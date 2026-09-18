import Foundation

/// The one click formats of the settings window. They are templates, not patterns, so the order
/// of the components is the locale's own: "Sep 18" in en_US and "18 сент." in ru_RU.
public enum FormatPreset: String, CaseIterable, Sendable {
  case dateOnly
  case dateAndWeekday
  case dateAndTime
  case compact
  case full

  /// `j` is the locale's preferred hour cycle, so the 12 or 24 hour setting is honoured.
  public var template: String {
    switch self {
    case .dateOnly: "dMMM"
    case .dateAndWeekday: "EdMMM"
    case .dateAndTime: "dMMMjmm"
    case .compact: "dM"
    case .full: "EEEEdMMMM"
    }
  }

  public func pattern(locale: Locale) -> String {
    DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: locale) ?? template
  }
}

public enum FormatValidationError: Error, Equatable, Sendable {
  case empty
  case unbalancedQuote
  case unsupportedField(Character)
  case fieldTooLong(Character)
}

/// Checks a hand written Unicode TR35 pattern. `DateFormatter` accepts anything and prints
/// nonsense for letters it does not know, so it cannot be the validator.
public enum FormatValidator {
  /// The longest run each supported field letter may have.
  /// `c` and `L` are the stand-alone weekday and month, which the locale templates produce for
  /// languages that inflect them, Russian among them.
  static let fieldLimits: [Character: Int] = [
    "E": 5, "c": 5, "d": 2, "M": 5, "L": 5, "y": 4, "H": 2, "h": 2, "m": 2, "s": 2, "a": 1,
    "w": 2,
  ]

  public static func validate(_ pattern: String) -> Result<Void, FormatValidationError> {
    var hasField = false
    var hasLiteral = false
    var inQuote = false
    var run: (letter: Character, count: Int)?

    func closeRun() -> FormatValidationError? {
      defer { run = nil }
      guard let run else { return nil }
      guard let limit = fieldLimits[run.letter] else { return .unsupportedField(run.letter) }
      return run.count > limit ? .fieldTooLong(run.letter) : nil
    }

    for character in pattern {
      if character == "'" {
        if let error = closeRun() { return .failure(error) }
        inQuote.toggle()
        continue
      }
      if inQuote {
        hasLiteral = true
        continue
      }
      if character.isASCII, character.isLetter {
        if let current = run, current.letter == character {
          run = (character, current.count + 1)
        } else {
          if let error = closeRun() { return .failure(error) }
          run = (character, 1)
        }
        hasField = true
      } else {
        if let error = closeRun() { return .failure(error) }
        if !character.isWhitespace { hasLiteral = true }
      }
    }
    if let error = closeRun() { return .failure(error) }
    if inQuote { return .failure(.unbalancedQuote) }
    if !hasField && !hasLiteral { return .failure(.empty) }
    return .success(())
  }

  public static func isValid(_ pattern: String) -> Bool {
    if case .success = validate(pattern) { return true }
    return false
  }
}

/// A cache of configured formatters. Creating a `DateFormatter` is expensive, so each pattern
/// gets one and keeps it until the locale, the calendar or the time zone changes.
public final class FormatterCache {
  private var formatters: [String: DateFormatter] = [:]
  public private(set) var calendar: Calendar
  public private(set) var locale: Locale

  public init(calendar: Calendar, locale: Locale) {
    self.calendar = calendar
    self.locale = locale
  }

  /// Drops every formatter. Called when the system locale, calendar or time zone changed.
  public func reset(calendar: Calendar, locale: Locale) {
    self.calendar = calendar
    self.locale = locale
    formatters.removeAll()
  }

  public var count: Int { formatters.count }

  public func formatter(pattern: String) -> DateFormatter {
    if let cached = formatters[pattern] { return cached }
    let formatter = DateFormatter()
    formatter.calendar = calendar
    formatter.locale = locale
    formatter.timeZone = calendar.timeZone
    formatter.dateFormat = pattern
    formatters[pattern] = formatter
    return formatter
  }

  public func string(from date: Date, pattern: String) -> String {
    formatter(pattern: pattern).string(from: date)
  }
}

/// The text of the menu bar item. An invalid pattern never produces an empty item: the last
/// pattern that worked is used instead.
public enum MenuBarText {
  public static func render(
    pattern: String, fallbackPattern: String, date: Date, cache: FormatterCache
  ) -> String {
    if FormatValidator.isValid(pattern) {
      let text = cache.string(from: date, pattern: pattern)
      if !text.trimmingCharacters(in: .whitespaces).isEmpty { return text }
    }
    let fallback = FormatValidator.isValid(fallbackPattern)
      ? fallbackPattern : FormatPreset.dateAndWeekday.pattern(locale: cache.locale)
    return cache.string(from: date, pattern: fallback)
  }
}
