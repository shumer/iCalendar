import Foundation

/// A stretch of days the user is off. Days, not hours: half days would need a second cell state
/// for a rare case. Stored as Gregorian day keys, so the file means the same in every calendar.
public struct VacationRange: Codable, Equatable, Identifiable, Sendable {
  public let id: UUID
  /// Inclusive, as `year * 10000 + month * 100 + day` in the Gregorian calendar.
  public var startKey: Int
  public var endKey: Int
  public var name: String

  public init(id: UUID = UUID(), startKey: Int, endKey: Int, name: String = "") {
    self.id = id
    self.startKey = min(startKey, endKey)
    self.endKey = max(startKey, endKey)
    self.name = name
  }

  public func contains(_ key: Int) -> Bool { (startKey...endKey).contains(key) }

  public func overlaps(_ other: VacationRange) -> Bool {
    startKey <= other.endKey && other.startKey <= endKey
  }
}

/// The user's vacations, with the operations the grid and the settings need. A value type, so
/// the store keeps one and writes it whenever it changes.
public struct VacationList: Codable, Equatable, Sendable {
  public private(set) var ranges: [VacationRange]

  public init(ranges: [VacationRange] = []) {
    self.ranges = ranges.sorted { $0.startKey < $1.startKey }
  }

  public var isEmpty: Bool { ranges.isEmpty }

  public func range(containing key: Int) -> VacationRange? {
    ranges.first { $0.contains(key) }
  }

  /// Adds a range. Ranges that touch or overlap it are merged into it, so marking the day after
  /// an existing vacation extends that vacation instead of starting a second one beside it.
  @discardableResult
  public mutating func add(_ range: VacationRange, calendar: Calendar) -> VacationRange {
    var merged = range
    var kept: [VacationRange] = []
    for existing in ranges {
      let touches = existing.overlaps(merged)
        || VacationCalendar.day(after: existing.endKey, calendar: calendar) == merged.startKey
        || VacationCalendar.day(after: merged.endKey, calendar: calendar) == existing.startKey
      if touches {
        merged = VacationRange(
          id: merged.id, startKey: min(existing.startKey, merged.startKey),
          endKey: max(existing.endKey, merged.endKey),
          name: merged.name.isEmpty ? existing.name : merged.name)
      } else {
        kept.append(existing)
      }
    }
    kept.append(merged)
    ranges = kept.sorted { $0.startKey < $1.startKey }
    return merged
  }

  /// Takes the days of `range` out of whatever vacations hold them. A vacation with days on both
  /// sides is split in two.
  public mutating func remove(_ range: VacationRange, calendar: Calendar) {
    var result: [VacationRange] = []
    for existing in ranges {
      guard existing.overlaps(range) else {
        result.append(existing)
        continue
      }
      if existing.startKey < range.startKey {
        result.append(
          VacationRange(
            startKey: existing.startKey,
            endKey: VacationCalendar.day(before: range.startKey, calendar: calendar),
            name: existing.name))
      }
      if existing.endKey > range.endKey {
        result.append(
          VacationRange(
            startKey: VacationCalendar.day(after: range.endKey, calendar: calendar),
            endKey: existing.endKey, name: existing.name))
      }
    }
    ranges = result.sorted { $0.startKey < $1.startKey }
  }

  public mutating func delete(id: UUID) {
    ranges.removeAll { $0.id == id }
  }

  public mutating func rename(id: UUID, to name: String) {
    guard let index = ranges.firstIndex(where: { $0.id == id }) else { return }
    ranges[index].name = name
  }
}

/// Answers "is this day a vacation" for the grid, in the same way `HolidayCalendar` does.
public struct VacationCalendar: IndicatorProvider, Equatable, Sendable {
  private let list: VacationList

  public init(_ list: VacationList) {
    self.list = list
  }

  public func indicators(for day: Date, calendar: Calendar) -> [DayIndicator] {
    guard let range = list.range(containing: Self.key(for: day, calendar: calendar)) else { return [] }
    return [DayIndicator(kind: .vacation, title: range.name)]
  }

  // MARK: Day keys

  public static func key(for day: Date, calendar: Calendar) -> Int {
    let parts = HolidayCalendar.gregorian(like: calendar).dateComponents([.year, .month, .day], from: day)
    return HolidayCalendar.key(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
  }

  public static func date(for key: Int, calendar: Calendar) -> Date? {
    let gregorian = HolidayCalendar.gregorian(like: calendar)
    return gregorian.date(from: DateComponents(year: key / 10_000, month: key / 100 % 100, day: key % 100))
  }

  static func day(after key: Int, calendar: Calendar) -> Int {
    shifted(key, by: 1, calendar: calendar)
  }

  static func day(before key: Int, calendar: Calendar) -> Int {
    shifted(key, by: -1, calendar: calendar)
  }

  private static func shifted(_ key: Int, by days: Int, calendar: Calendar) -> Int {
    let gregorian = HolidayCalendar.gregorian(like: calendar)
    guard let date = date(for: key, calendar: calendar),
      let moved = gregorian.date(byAdding: .day, value: days, to: date)
    else { return key }
    return self.key(for: moved, calendar: calendar)
  }

  /// The number of days in an inclusive range of keys.
  public static func dayCount(from startKey: Int, to endKey: Int, calendar: Calendar) -> Int {
    let gregorian = HolidayCalendar.gregorian(like: calendar)
    guard let start = date(for: startKey, calendar: calendar), let end = date(for: endKey, calendar: calendar),
      let days = gregorian.dateComponents([.day], from: start, to: end).day
    else { return 1 }
    return abs(days) + 1
  }
}

/// Several providers as one: holidays and vacations both mark days, and the engine takes one.
public struct CompositeIndicatorProvider: IndicatorProvider {
  private let providers: [any IndicatorProvider]

  public init(_ providers: [any IndicatorProvider]) {
    self.providers = providers
  }

  public func indicators(for day: Date, calendar: Calendar) -> [DayIndicator] {
    providers.flatMap { $0.indicators(for: day, calendar: calendar) }
  }
}
