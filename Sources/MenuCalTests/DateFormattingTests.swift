import Foundation
import MenuCalCore

func dateFormattingTests(_ run: TestRun) {
  let moment: (Calendar) -> Date = { Fixtures.date(2026, 9, 18, 21, 30, 5, in: $0) }

  func text(_ preset: FormatPreset, _ localeID: String) -> String {
    let calendar = Fixtures.calendar(.gregorian, locale: localeID)
    let locale = Locale(identifier: localeID)
    let cache = FormatterCache(calendar: calendar, locale: locale)
    return cache.string(from: moment(calendar), pattern: preset.pattern(locale: locale))
  }

  /// Exact strings depend on the ICU data of the OS the suite runs on, so the presets are
  /// checked for what they promise: which components appear, and in which order.
  func expectOrder(_ t: TestRun, _ text: String, _ parts: [String], line: UInt = #line) {
    let lowered = text.lowercased()
    var cursor = lowered.startIndex
    for part in parts {
      guard let found = lowered.range(of: part.lowercased(), range: cursor..<lowered.endIndex) else {
        t.expect(false, "\(text) should contain \(parts) in this order", line: line)
        return
      }
      cursor = found.upperBound
    }
  }

  run.test("presets put the components in the locale's order") { t in
    expectOrder(t, text(.dateOnly, "en_US"), ["sep", "18"])
    expectOrder(t, text(.dateOnly, "ru_RU"), ["18", "сент"])
    expectOrder(t, text(.dateAndWeekday, "en_US"), ["fri", "sep", "18"])
    expectOrder(t, text(.dateAndWeekday, "ru_RU"), ["пт", "18", "сент"])
    expectOrder(t, text(.full, "en_US"), ["friday", "september", "18"])
    expectOrder(t, text(.full, "pl_PL"), ["piątek", "18", "września"])
    expectOrder(t, text(.compact, "en_US"), ["9", "18"])
    expectOrder(t, text(.compact, "pl_PL"), ["18", "09"])
    t.expect(!text(.dateOnly, "en_US").contains("2026"), "no year in the short presets")
  }

  run.test("the time preset follows the locale's hour cycle") { t in
    t.expect(text(.dateAndTime, "en_US").contains("9:30"), text(.dateAndTime, "en_US"))
    t.expect(text(.dateAndTime, "en_US").contains("PM"))
    t.expect(text(.dateAndTime, "ru_RU").contains("21:30"), text(.dateAndTime, "ru_RU"))
  }

  run.test("every preset is a valid pattern in every locale") { t in
    for localeID in ["en_US", "ru_RU", "uk_UA", "pl_PL", "ar_SA", "he_IL", "ja_JP"] {
      for preset in FormatPreset.allCases {
        let pattern = preset.pattern(locale: Locale(identifier: localeID))
        t.expect(FormatValidator.isValid(pattern), "\(localeID) \(preset): \(pattern)")
        t.expect(!text(preset, localeID).isEmpty)
      }
    }
  }

  run.test("the validator accepts the documented fields") { t in
    for pattern in ["E d MMM", "EEEE, d MMMM yyyy", "dd.MM.yy", "HH:mm:ss", "h:mm a", "'W'w", "d MMM 'at' HH:mm", "LLLL"] {
      t.expect(FormatValidator.isValid(pattern), pattern)
    }
  }

  run.test("the validator names what is wrong") { t in
    func error(_ pattern: String) -> FormatValidationError? {
      if case .failure(let error) = FormatValidator.validate(pattern) { return error }
      return nil
    }
    t.expectEqual(error(""), .empty)
    t.expectEqual(error("   "), .empty)
    t.expectEqual(error("d MMM 'oops"), .unbalancedQuote)
    t.expectEqual(error("d Q"), .unsupportedField("Q"))
    t.expectEqual(error("ddd"), .fieldTooLong("d"))
    t.expectEqual(error("MMMMMM"), .fieldTooLong("M"))
    t.expectEqual(error("aa"), .fieldTooLong("a"))
  }

  run.test("quoted text is never read as fields") { t in
    t.expect(FormatValidator.isValid("'Today is' EEEE"))
    t.expect(FormatValidator.isValid("d''MMM"))
    t.expect(FormatValidator.isValid("'QQQ'"))
  }

  run.test("an invalid pattern falls back to the last valid one") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    let cache = FormatterCache(calendar: calendar, locale: Locale(identifier: "en_US"))
    let shown = MenuBarText.render(pattern: "d QQ", fallbackPattern: "d MMM", date: moment(calendar), cache: cache)
    t.expectEqual(shown, "18 Sep")
  }

  run.test("with no usable fallback the default preset is shown, never an empty item") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    let cache = FormatterCache(calendar: calendar, locale: Locale(identifier: "en_US"))
    let shown = MenuBarText.render(pattern: "", fallbackPattern: "'", date: moment(calendar), cache: cache)
    t.expectEqual(shown, "Fri, Sep 18")
  }

  run.test("a valid pattern is rendered as written") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "ru_RU")
    let cache = FormatterCache(calendar: calendar, locale: Locale(identifier: "ru_RU"))
    let shown = MenuBarText.render(pattern: "EEEE, d MMMM", fallbackPattern: "d", date: moment(calendar), cache: cache)
    t.expectEqual(shown, "пятница, 18 сентября")
  }

  run.test("formatters are created once per pattern and dropped on reset") { t in
    let calendar = Fixtures.calendar(.gregorian, locale: "en_US")
    let cache = FormatterCache(calendar: calendar, locale: Locale(identifier: "en_US"))
    let first = cache.formatter(pattern: "d MMM")
    t.expect(first === cache.formatter(pattern: "d MMM"))
    _ = cache.formatter(pattern: "HH:mm")
    t.expectEqual(cache.count, 2)

    let russian = Fixtures.calendar(.gregorian, locale: "ru_RU")
    cache.reset(calendar: russian, locale: Locale(identifier: "ru_RU"))
    t.expectEqual(cache.count, 0)
    t.expectEqual(cache.string(from: moment(russian), pattern: "d MMM"), "18 сент.")
  }

  run.test("the cache follows the calendar's time zone") { t in
    let tokyo = Fixtures.calendar(.gregorian, locale: "en_US", timeZone: "Asia/Tokyo")
    let warsaw = Fixtures.calendar(.gregorian, locale: "en_US")
    let cache = FormatterCache(calendar: tokyo, locale: Locale(identifier: "en_US"))
    t.expectEqual(cache.string(from: Fixtures.date(2026, 9, 18, 23, 30, in: warsaw), pattern: "d"), "19")
  }
}
