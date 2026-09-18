import Foundation

// MARK: - Model

/// Something the grid knows about a day beyond its date. The brief reserved this for events;
/// public holidays are its first use.
public struct DayIndicator: Equatable, Sendable {
  public enum Kind: Equatable, Sendable {
    case publicHoliday
  }

  public let kind: Kind
  public let title: String

  public init(kind: Kind, title: String) {
    self.kind = kind
    self.title = title
  }
}

/// The extension point for whatever marks days: `HolidayCalendar` today, events some day.
public protocol IndicatorProvider {
  func indicators(for day: Date, calendar: Calendar) -> [DayIndicator]
}

public struct DayCellModel: Identifiable, Equatable, Sendable {
  /// The start of the day in the grid's calendar.
  public let id: Date
  public let date: Date
  /// Localised digits, which matters for Arabic and Persian.
  public let dayNumber: String
  public let isInCurrentMonth: Bool
  public let isToday: Bool
  public let isWeekend: Bool
  public let accessibilityLabel: String
  public let indicators: [DayIndicator]

  /// The name of the public holiday on this day, if it is one.
  public var holidayName: String? {
    indicators.first { $0.kind == .publicHoliday }?.title
  }
}

public struct WeekRow: Identifiable, Equatable, Sendable {
  public let id: Int
  public let weekOfYear: Int
  /// Localised digits of `weekOfYear`.
  public let weekNumber: String
  /// Exactly 7.
  public let days: [DayCellModel]
}

public struct WeekdaySymbol: Equatable, Sendable {
  public let short: String
  public let veryShort: String
  public let full: String
  public let isWeekend: Bool
}

public struct MonthGrid: Equatable, Sendable {
  /// The first day of the displayed month.
  public let referenceDate: Date
  /// Exactly 6, so the panel never changes height between months.
  public let weeks: [WeekRow]
  /// Month and year in the locale's own order, for accessibility and window titles.
  public let monthTitle: String
  /// The stand-alone month name with its first letter capitalised by the locale's rules.
  public let monthName: String
  public let yearText: String
  /// Already ordered by the first weekday.
  public let weekdaySymbols: [WeekdaySymbol]

  public var days: [DayCellModel] { weeks.flatMap(\.days) }
}

// MARK: - Formatters

/// The date formatters one grid needs. They are expensive to create, so the caller builds this
/// once per calendar and locale and hands it to every `makeGrid` call until either changes.
public final class GridFormatters {
  let calendar: Calendar
  let locale: Locale
  let dayNumber: DateFormatter
  let monthName: DateFormatter
  let year: DateFormatter
  let monthTitle: DateFormatter
  let accessibility: DateFormatter
  let weekNumber: NumberFormatter

  public init(calendar: Calendar, locale: Locale) {
    self.calendar = calendar
    self.locale = locale

    func formatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
      let formatter = DateFormatter()
      formatter.calendar = calendar
      formatter.locale = locale
      formatter.timeZone = calendar.timeZone
      configure(formatter)
      return formatter
    }

    dayNumber = formatter { $0.dateFormat = "d" }
    monthName = formatter { $0.dateFormat = "LLLL" }
    // A Japanese year is a number within an era, and means nothing without it.
    let yearTemplate = calendar.identifier == .japanese ? "Gy" : "y"
    year = formatter { $0.setLocalizedDateFormatFromTemplate(yearTemplate) }
    monthTitle = formatter { $0.setLocalizedDateFormatFromTemplate("yMMMM") }
    accessibility = formatter { $0.dateStyle = .full }

    weekNumber = NumberFormatter()
    weekNumber.locale = locale
    weekNumber.numberStyle = .none
  }
}

// MARK: - Engine

/// Builds the month grid. A pure function of its arguments: it never reads the clock, the
/// current locale or any shared state, which is what makes it testable on every calendar.
public enum CalendarEngine {
  public static let weekCount = 6
  public static let daysPerWeek = 7

  /// The calendar the grid is built with: the given one, with the first weekday replaced when
  /// the user overrides the system's choice.
  public static func effectiveCalendar(_ calendar: Calendar, firstWeekdayOverride: Int?) -> Calendar {
    guard let override = firstWeekdayOverride, (1...7).contains(override) else { return calendar }
    var adjusted = calendar
    adjusted.firstWeekday = override
    return adjusted
  }

  public static func makeGrid(
    for referenceDate: Date,
    today: Date,
    calendar: Calendar,
    locale: Locale,
    firstWeekdayOverride: Int? = nil,
    formatters: GridFormatters? = nil,
    indicatorProvider: (any IndicatorProvider)? = nil
  ) -> MonthGrid {
    let calendar = localized(
      effectiveCalendar(calendar, firstWeekdayOverride: firstWeekdayOverride), locale: locale)
    let formatters = formatters ?? GridFormatters(calendar: calendar, locale: locale)

    let monthStart = startOfMonth(for: referenceDate, calendar: calendar)
    let weekdayOfFirst = calendar.component(.weekday, from: monthStart)
    let leadingDays = (weekdayOfFirst - calendar.firstWeekday + daysPerWeek) % daysPerWeek
    let gridStart = day(monthStart, offsetBy: -leadingDays, calendar: calendar)

    var weeks: [WeekRow] = []
    weeks.reserveCapacity(weekCount)
    for row in 0..<weekCount {
      var days: [DayCellModel] = []
      days.reserveCapacity(daysPerWeek)
      for column in 0..<daysPerWeek {
        let date = day(gridStart, offsetBy: row * daysPerWeek + column, calendar: calendar)
        let indicators = indicatorProvider?.indicators(for: date, calendar: calendar) ?? []
        // VoiceOver hears the holiday with the date, since red text says nothing to it.
        let spoken = ([formatters.accessibility.string(from: date)] + indicators.map(\.title))
          .joined(separator: ", ")
        days.append(
          DayCellModel(
            id: date,
            date: date,
            dayNumber: formatters.dayNumber.string(from: date),
            isInCurrentMonth: calendar.isDate(date, equalTo: monthStart, toGranularity: .month),
            isToday: calendar.isDate(date, inSameDayAs: today),
            isWeekend: calendar.isDateInWeekend(date),
            accessibilityLabel: spoken,
            indicators: indicators))
      }
      let weekOfYear = calendar.component(.weekOfYear, from: days[0].date)
      weeks.append(
        WeekRow(
          id: row,
          weekOfYear: weekOfYear,
          weekNumber: formatters.weekNumber.string(from: NSNumber(value: weekOfYear)) ?? "\(weekOfYear)",
          days: days))
    }

    return MonthGrid(
      referenceDate: monthStart,
      weeks: weeks,
      monthTitle: formatters.monthTitle.string(from: monthStart),
      monthName: capitalizingFirstLetter(formatters.monthName.string(from: monthStart), locale: locale),
      yearText: formatters.year.string(from: monthStart),
      weekdaySymbols: weekdaySymbols(firstRow: weeks[0], calendar: calendar))
  }

  // MARK: Pieces

  /// The calendar with the locale its symbols are read in. Assigning a locale also resets the
  /// first weekday and the first week rule to that locale's defaults, which would throw away
  /// what the user chose in System Settings or in the app, so both are put back.
  static func localized(_ calendar: Calendar, locale: Locale) -> Calendar {
    var localized = calendar
    localized.locale = locale
    localized.firstWeekday = calendar.firstWeekday
    localized.minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
    return localized
  }

  public static func startOfMonth(for date: Date, calendar: Calendar) -> Date {
    calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
  }

  /// Day arithmetic goes through the calendar and never through 86400 seconds: a day can be 23
  /// or 25 hours long, and in some time zones midnight does not exist on the day the clocks move.
  static func day(_ start: Date, offsetBy days: Int, calendar: Calendar) -> Date {
    let moved = calendar.date(byAdding: .day, value: days, to: start) ?? start
    return calendar.startOfDay(for: moved)
  }

  private static func weekdaySymbols(firstRow: WeekRow, calendar: Calendar) -> [WeekdaySymbol] {
    let short = calendar.shortStandaloneWeekdaySymbols
    let veryShort = calendar.veryShortStandaloneWeekdaySymbols
    let full = calendar.standaloneWeekdaySymbols
    return firstRow.days.map { day in
      // Weekday 1 is Sunday in every calendar, and the symbol arrays start at Sunday too.
      let index = calendar.component(.weekday, from: day.date) - 1
      return WeekdaySymbol(
        short: short[index], veryShort: veryShort[index], full: full[index],
        isWeekend: day.isWeekend)
    }
  }

  static func capitalizingFirstLetter(_ text: String, locale: Locale) -> String {
    guard let first = text.first else { return text }
    return String(first).uppercased(with: locale) + text.dropFirst()
  }
}
