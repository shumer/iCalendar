import Foundation

/// How often the menu bar text can change, which decides when the app has to wake up.
public enum RefreshGranularity: Int, Sendable, Comparable {
  case day
  case minute
  case second

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

/// Decides when the menu bar text must be redrawn, so the app sleeps until the text can change
/// and never polls. A date only format wakes once a day.
public enum RefreshSchedule {
  /// The finest unit a Unicode TR35 pattern shows. Quoted literals are skipped.
  public static func granularity(ofPattern pattern: String) -> RefreshGranularity {
    var result = RefreshGranularity.day
    var inQuote = false
    for character in pattern {
      if character == "'" {
        inQuote.toggle()
        continue
      }
      if inQuote { continue }
      switch character {
      case "s", "S", "A":
        return .second
      case "m", "H", "h", "K", "k", "j", "a", "b", "B":
        result = max(result, .minute)
      default:
        break
      }
    }
    return result
  }

  /// The first moment after `now` at which a text of this granularity changes. It is the end of
  /// the calendar unit that holds `now`, so daylight saving shifts and odd time zones are the
  /// calendar's problem, not ours.
  public static func nextFire(
    after now: Date,
    granularity: RefreshGranularity,
    calendar: Calendar
  ) -> Date {
    let component: Calendar.Component
    let fallback: TimeInterval
    switch granularity {
    case .day:
      component = .day
      fallback = 86_400
    case .minute:
      component = .minute
      fallback = 60
    case .second:
      component = .second
      fallback = 1
    }
    guard let interval = calendar.dateInterval(of: component, for: now), interval.end > now else {
      return now.addingTimeInterval(fallback)
    }
    return interval.end
  }

  /// How late a timer of this granularity may fire. A date can be a few seconds late without
  /// anybody noticing; a seconds display cannot.
  public static func tolerance(for granularity: RefreshGranularity) -> TimeInterval {
    switch granularity {
    case .day: 5
    case .minute: 0.5
    case .second: 0.05
    }
  }
}
