import Foundation
import MenuCalCore

@MainActor
func preferencesTests(_ run: TestRun) {
  /// A throwaway defaults domain, so the suite never reads or writes the app's real settings.
  func scratchDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let suite = "com.shumenko.menucal.tests.\(name)"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    return defaults
  }
  let english = Locale(identifier: "en_US")

  run.test("a first launch gets the documented defaults") { t in
    let preferences = Preferences(defaults: scratchDefaults())
    t.expectEqual(preferences.formatPreset, .dateAndWeekday)
    t.expectEqual(preferences.menuBarIcon, MenuBarIcon.none)
    t.expectEqual(preferences.firstWeekday, .system)
    t.expect(!preferences.showsWeekNumbers)
    t.expect(preferences.showsFullDate)
    t.expect(preferences.highlightsWeekends)
    t.expectEqual(preferences.reopenBehavior, .currentMonth)
    t.expectEqual(preferences.appearance, .system)
    t.expectEqual(preferences.density, .regular)
    t.expect(!preferences.usesCustomAccent)
    t.expect(preferences.checksForUpdatesAutomatically)
    t.expectEqual(preferences.lastViewedMonth, nil)
    t.expectEqual(preferences.menuBarPattern(locale: english), FormatPreset.dateAndWeekday.pattern(locale: english))
  }

  run.test("every change is stored at once and read back by a new instance") { t in
    let defaults = scratchDefaults()
    let month = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let first = Preferences(defaults: defaults)
    first.formatPreset = nil
    first.customPattern = "EEEE d"
    first.lastValidPattern = "EEEE d"
    first.menuBarIcon = .dayNumber
    first.firstWeekday = .saturday
    first.showsWeekNumbers = true
    first.showsFullDate = false
    first.highlightsWeekends = false
    first.reopenBehavior = .lastViewedMonth
    first.lastViewedMonth = month
    first.appearance = .dark
    first.density = .compact
    first.usesCustomAccent = true
    first.customAccent = AccentComponents(red: 1, green: 0.5, blue: 0.25)
    first.checksForUpdatesAutomatically = false

    let second = Preferences(defaults: defaults)
    t.expectEqual(second.formatPreset, nil)
    t.expectEqual(second.menuBarPattern(locale: english), "EEEE d")
    t.expectEqual(second.menuBarIcon, .dayNumber)
    t.expectEqual(second.firstWeekday, .saturday)
    t.expectEqual(second.firstWeekday.weekday, 7)
    t.expect(second.showsWeekNumbers && !second.showsFullDate && !second.highlightsWeekends)
    t.expectEqual(second.reopenBehavior, .lastViewedMonth)
    t.expectEqual(second.lastViewedMonth, month)
    t.expectEqual(second.appearance, .dark)
    t.expectEqual(second.density, .compact)
    t.expect(second.usesCustomAccent)
    t.expectEqual(second.customAccent, AccentComponents(red: 1, green: 0.5, blue: 0.25))
    t.expect(!second.checksForUpdatesAutomatically)

    second.lastViewedMonth = nil
    t.expectEqual(Preferences(defaults: defaults).lastViewedMonth, nil)
  }

  run.test("values this version cannot read fall back key by key") { t in
    let defaults = scratchDefaults()
    defaults.set("hologram", forKey: "menuBar.icon")
    defaults.set("friday", forKey: "calendar.firstWeekday")
    defaults.set("sepia", forKey: "appearance.theme")
    defaults.set("yes please", forKey: "calendar.showsWeekNumbers")
    defaults.set([2.0, -1.0], forKey: "appearance.customAccent")
    defaults.set("compact", forKey: "appearance.density")
    let preferences = Preferences(defaults: defaults)
    t.expectEqual(preferences.menuBarIcon, MenuBarIcon.none)
    t.expectEqual(preferences.firstWeekday, .system)
    t.expectEqual(preferences.appearance, .system)
    t.expect(!preferences.showsWeekNumbers)
    t.expectEqual(preferences.customAccent, AccentComponents(red: 0, green: 0.478, blue: 1))
    t.expectEqual(preferences.density, .compact, "a good value next to bad ones is kept")
  }

  run.test("a stored custom pattern that is invalid does not reach the menu bar") { t in
    let defaults = scratchDefaults()
    defaults.set("custom", forKey: "format.preset")
    defaults.set("d QQQ", forKey: "format.customPattern")
    defaults.set("'", forKey: "format.lastValidPattern")
    let preferences = Preferences(defaults: defaults)
    t.expectEqual(preferences.formatPreset, .dateAndWeekday)
    t.expectEqual(preferences.lastValidPattern, "")
    t.expectEqual(preferences.fallbackPattern(locale: english), FormatPreset.dateAndWeekday.pattern(locale: english))
  }

  run.test("an invalid custom pattern gives way to the last valid one before any preset") { t in
    let defaults = scratchDefaults()
    defaults.set("custom", forKey: "format.preset")
    defaults.set("d QQQ", forKey: "format.customPattern")
    defaults.set("EEEE d", forKey: "format.lastValidPattern")
    let preferences = Preferences(defaults: defaults)
    t.expectEqual(preferences.formatPreset, nil)
    t.expectEqual(preferences.menuBarPattern(locale: english), "EEEE d")
  }

  run.test("no shortcut is assigned by default, and an assigned one survives a relaunch") { t in
    let defaults = scratchDefaults()
    let preferences = Preferences(defaults: defaults)
    t.expectEqual(preferences.hotkey, nil)
    preferences.hotkey = Hotkey(keyCode: 8, modifiers: [.option, .command])
    t.expectEqual(Preferences(defaults: defaults).hotkey, Hotkey(keyCode: 8, modifiers: [.option, .command]))
    preferences.hotkey = nil
    t.expectEqual(Preferences(defaults: defaults).hotkey, nil)
  }

  run.test("a stored shortcut that would swallow typing is dropped") { t in
    let defaults = scratchDefaults()
    defaults.set([8, 4], forKey: "hotkey.togglePanel")
    t.expectEqual(Preferences(defaults: defaults).hotkey, nil, "Shift+C is typing")
    defaults.set([8], forKey: "hotkey.togglePanel")
    t.expectEqual(Preferences(defaults: defaults).hotkey, nil)
    defaults.set([8, 99], forKey: "hotkey.togglePanel")
    t.expectEqual(Preferences(defaults: defaults).hotkey, nil)
  }

  run.test("shortcut rules and symbols") { t in
    t.expect(Hotkey(keyCode: 8, modifiers: [.command]).isUsable)
    t.expect(Hotkey(keyCode: 8, modifiers: [.control, .shift]).isUsable)
    t.expect(!Hotkey(keyCode: 8, modifiers: []).isUsable)
    t.expect(!Hotkey(keyCode: 8, modifiers: [.shift]).isUsable)
    t.expect(Hotkey(keyCode: 122, modifiers: []).isUsable, "F1 alone is fine")
    t.expectEqual(HotkeyModifiers([.command, .control, .shift, .option]).symbols, "⌃⌥⇧⌘")
  }

  run.test("the fallback is the last pattern that worked") { t in
    let preferences = Preferences(defaults: scratchDefaults())
    preferences.lastValidPattern = "d MMM"
    t.expectEqual(preferences.fallbackPattern(locale: english), "d MMM")
  }

  run.test("the weekday preference maps to Calendar's numbering") { t in
    t.expectEqual(FirstWeekdayPreference.system.weekday, nil)
    t.expectEqual(FirstWeekdayPreference.sunday.weekday, 1)
    t.expectEqual(FirstWeekdayPreference.monday.weekday, 2)
  }
}
