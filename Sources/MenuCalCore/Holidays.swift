import Foundation

/// An official public holiday: a day off for the whole country.
public struct Holiday: Codable, Equatable, Sendable {
  public let year: Int
  public let month: Int
  public let day: Int
  /// The name in the country's own language.
  public let localName: String
  /// The name in English.
  public let name: String

  public init(year: Int, month: Int, day: Int, localName: String, name: String) {
    self.year = year
    self.month = month
    self.day = day
    self.localName = localName
    self.name = name
  }

  var key: Int { HolidayCalendar.key(year: year, month: month, day: day) }
}

public enum HolidayFeedError: Error, Equatable, Sendable {
  case malformed
}

/// Reads the Nager.Date public holiday list for one country and one year. The decision to use
/// it, and what it costs, is in docs/adr/0004-public-holidays.md.
public enum HolidayFeed {
  /// Countries the service knows, so that a request is never made for one it does not.
  public static let supportedCountries: Set<String> = Set(
    (
      "AD AG AI AL AM AO AR AT AU AW AX BA BB BD BE BF BG BH BI BJ BL BM BO BQ BR BS BW BY BZ " +
      "CA CC CD CF CG CH CI CK CL CM CN CO CR CU CV CW CX CY CZ DE DJ DK DM DO DZ EC EE EG ER " +
      "ES ET FI FK FM FO FR GA GB GD GE GF GG GH GI GL GM GN GP GQ GR GT GW GY HK HN HR HT HU " +
      "ID IE IM IQ IS IT JE JM JP KE KH KI KM KN KR KY KZ LC LI LR LS LT LU LV LY MA MC MD ME " +
      "MF MG MH MK ML MN MP MQ MR MS MT MW MX MZ NA NC NE NF NG NI NL NO NR NU NZ PA PE PF PG " +
      "PH PL PM PN PR PT PW PY RO RS RU RW SB SC SD SE SG SH SI SJ SK SL SM SN SO SR SS ST SV " +
      "SX SY SZ TC TD TG TK TN TO TR TT TV TZ UA UG US UY VA VC VE VG VI VN VU WF WS YE ZA ZM " +
      "ZW"
    ).split(separator: " ").map(String.init))

  /// Nil for a country the service does not know or a code that is not two capital letters.
  public static func url(country: String, year: Int) -> URL? {
    guard supportedCountries.contains(country), (1900...2200).contains(year) else { return nil }
    return URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/\(country)")
  }

  /// Keeps what the user asked for, official days off: entries of the type "Public" that hold
  /// for the whole country. Bank and school holidays, observances and regional days are dropped.
  public static func parse(_ data: Data, year: Int) throws -> [Holiday] {
    guard let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      throw HolidayFeedError.malformed
    }
    return entries.compactMap { entry in
      guard let types = entry["types"] as? [String], types.contains("Public"),
        entry["global"] as? Bool == true,
        let date = entry["date"] as? String,
        let name = entry["name"] as? String
      else { return nil }
      let parts = date.split(separator: "-").compactMap { Int($0) }
      guard parts.count == 3, parts[0] == year, (1...12).contains(parts[1]), (1...31).contains(parts[2])
      else { return nil }
      let local = (entry["localName"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? name
      return Holiday(year: parts[0], month: parts[1], day: parts[2], localName: local, name: name)
    }
  }
}

/// One country and one year of holidays as they are kept on disk.
public struct HolidayCacheEntry: Codable, Equatable, Sendable {
  public let country: String
  public let year: Int
  public let fetchedAt: Date
  public let holidays: [Holiday]

  public init(country: String, year: Int, fetchedAt: Date, holidays: [Holiday]) {
    self.country = country
    self.year = year
    self.fetchedAt = fetchedAt
    self.holidays = holidays
  }
}

public enum HolidayPolicy {
  /// Governments do move holidays, but not often: a month old list is fresh enough, and a list
  /// of a year that is over never changes again.
  public static let refreshInterval: TimeInterval = 30 * 24 * 60 * 60

  public static func needsFetch(_ entry: HolidayCacheEntry?, now: Date, currentYear: Int) -> Bool {
    guard let entry else { return true }
    if entry.year < currentYear { return false }
    return entry.fetchedAt > now || now.timeIntervalSince(entry.fetchedAt) >= refreshInterval
  }

  /// The country whose holidays are shown: the one picked in settings, or the region of the
  /// system. The region is a setting the user controls, so no location permission is involved.
  public static func country(override: String?, locale: Locale) -> String? {
    let code = (override ?? locale.region?.identifier)?.uppercased()
    guard let code, HolidayFeed.supportedCountries.contains(code) else { return nil }
    return code
  }

  /// The same answer before the grid exists: a grid starts at most six days before its month
  /// and ends at most forty two days after that, so these two dates bracket it.
  public static func years(around monthStart: Date, calendar: Calendar) -> Set<Int> {
    let gregorian = HolidayCalendar.gregorian(like: calendar)
    let first = gregorian.date(byAdding: .day, value: -6, to: monthStart) ?? monthStart
    let last = gregorian.date(byAdding: .day, value: 41, to: monthStart) ?? monthStart
    return [gregorian.component(.year, from: first), gregorian.component(.year, from: last)]
  }

  /// The Gregorian years a month grid touches: usually one, two around the new year.
  public static func years(of grid: MonthGrid, calendar: Calendar) -> Set<Int> {
    let gregorian = HolidayCalendar.gregorian(like: calendar)
    let days = grid.days
    guard let first = days.first, let last = days.last else { return [] }
    return [gregorian.component(.year, from: first.date), gregorian.component(.year, from: last.date)]
  }
}

/// Answers "is this day a public holiday" for the grid. Holidays are Gregorian dates, so the day
/// is read in a Gregorian calendar of the same time zone whatever calendar the grid is drawn in.
public struct HolidayCalendar: IndicatorProvider, Equatable, Sendable {
  private let names: [Int: String]

  public init(_ holidays: [Holiday], prefersLocalNames: Bool = true) {
    var names: [Int: String] = [:]
    for holiday in holidays {
      names[holiday.key] = prefersLocalNames ? holiday.localName : holiday.name
    }
    self.names = names
  }

  public var isEmpty: Bool { names.isEmpty }

  public func name(on day: Date, calendar: Calendar) -> String? {
    let parts = Self.gregorian(like: calendar).dateComponents([.year, .month, .day], from: day)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return nil }
    return names[Self.key(year: year, month: month, day: day)]
  }

  public func indicators(for day: Date, calendar: Calendar) -> [DayIndicator] {
    name(on: day, calendar: calendar).map { [DayIndicator(kind: .publicHoliday, title: $0)] } ?? []
  }

  static func key(year: Int, month: Int, day: Int) -> Int { year * 10_000 + month * 100 + day }

  static func gregorian(like calendar: Calendar) -> Calendar {
    var gregorian = Calendar(identifier: .gregorian)
    gregorian.timeZone = calendar.timeZone
    return gregorian
  }
}
