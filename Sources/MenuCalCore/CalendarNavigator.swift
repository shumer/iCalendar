import Foundation

/// Which way the month slide moves. Chronological, so RTL mirroring is the view's business.
public enum NavigationDirection: Sendable {
  case backward
  case none
  case forward
}

/// Moving between days, months and years. Everything goes through `Calendar`, so a Hebrew leap
/// year has its thirteen months and the 31st clamps to the last day of a shorter month.
public enum CalendarNavigator {
  /// The first day of the month `months` away from the month holding `date`.
  public static func month(byAdding months: Int, to date: Date, calendar: Calendar) -> Date {
    let start = CalendarEngine.startOfMonth(for: date, calendar: calendar)
    let moved = calendar.date(byAdding: .month, value: months, to: start) ?? start
    return CalendarEngine.startOfMonth(for: moved, calendar: calendar)
  }

  /// The first day of the same month `years` away, clamped by the calendar when that month does
  /// not exist in the target year.
  public static func month(byAddingYears years: Int, to date: Date, calendar: Calendar) -> Date {
    let start = CalendarEngine.startOfMonth(for: date, calendar: calendar)
    let moved = calendar.date(byAdding: .year, value: years, to: start) ?? start
    return CalendarEngine.startOfMonth(for: moved, calendar: calendar)
  }

  public static func day(byAdding days: Int, to date: Date, calendar: Calendar) -> Date {
    CalendarEngine.day(calendar.startOfDay(for: date), offsetBy: days, calendar: calendar)
  }

  public static func isSameMonth(_ a: Date, _ b: Date, calendar: Calendar) -> Bool {
    calendar.isDate(a, equalTo: b, toGranularity: .month)
  }

  /// The direction from the month holding `from` to the month holding `to`.
  public static func direction(from: Date, to: Date, calendar: Calendar) -> NavigationDirection {
    if isSameMonth(from, to, calendar: calendar) { return .none }
    return to > from ? .forward : .backward
  }
}
