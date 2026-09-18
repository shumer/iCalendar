import Foundation
import Observation

public enum MenuBarIcon: String, CaseIterable, Sendable {
  case none
  case calendar
  case dayNumber
}

public enum FirstWeekdayPreference: String, CaseIterable, Sendable {
  case system
  case monday
  case sunday
  case saturday

  /// The `Calendar.firstWeekday` value, or nil to leave the system's choice alone.
  public var weekday: Int? {
    switch self {
    case .system: nil
    case .sunday: 1
    case .monday: 2
    case .saturday: 7
    }
  }
}

public enum ReopenBehavior: String, CaseIterable, Sendable {
  case currentMonth
  case lastViewedMonth
}

public enum AppearancePreference: String, CaseIterable, Sendable {
  case system
  case light
  case dark
}

public enum Density: String, CaseIterable, Sendable {
  case regular
  case compact
}

/// A colour the user picked, as plain sRGB components so that the core needs no AppKit.
public struct AccentComponents: Equatable, Sendable {
  public var red: Double
  public var green: Double
  public var blue: Double

  public init(red: Double, green: Double, blue: Double) {
    self.red = red
    self.green = green
    self.blue = blue
  }
}

/// The one place settings are read and written. Views bind to it and never touch
/// `UserDefaults` or `@AppStorage` themselves; every change is stored at once, so there is no
/// Apply button anywhere.
@MainActor
@Observable
public final class Preferences {
  private enum Key {
    static let formatPreset = "format.preset"
    static let customPattern = "format.customPattern"
    static let lastValidPattern = "format.lastValidPattern"
    static let menuBarIcon = "menuBar.icon"
    static let firstWeekday = "calendar.firstWeekday"
    static let showsWeekNumbers = "calendar.showsWeekNumbers"
    static let showsFullDate = "calendar.showsFullDate"
    static let highlightsWeekends = "calendar.highlightsWeekends"
    static let reopenBehavior = "calendar.reopenBehavior"
    static let lastViewedMonth = "calendar.lastViewedMonth"
    static let appearance = "appearance.theme"
    static let density = "appearance.density"
    static let usesCustomAccent = "appearance.usesCustomAccent"
    static let customAccent = "appearance.customAccent"
    static let checksForUpdates = "updates.automatic"
    static let hotkey = "hotkey.togglePanel"
  }

  /// The stored value for "the pattern is hand written".
  private static let customPresetMarker = "custom"

  @ObservationIgnored private let defaults: UserDefaults

  /// Nil means the hand written `customPattern` is in use.
  public var formatPreset: FormatPreset? {
    didSet { defaults.set(formatPreset?.rawValue ?? Self.customPresetMarker, forKey: Key.formatPreset) }
  }
  public var customPattern: String {
    didSet { defaults.set(customPattern, forKey: Key.customPattern) }
  }
  /// The last hand written pattern that passed validation; shown while the field holds a bad one.
  public var lastValidPattern: String {
    didSet { defaults.set(lastValidPattern, forKey: Key.lastValidPattern) }
  }
  public var menuBarIcon: MenuBarIcon {
    didSet { defaults.set(menuBarIcon.rawValue, forKey: Key.menuBarIcon) }
  }
  public var firstWeekday: FirstWeekdayPreference {
    didSet { defaults.set(firstWeekday.rawValue, forKey: Key.firstWeekday) }
  }
  public var showsWeekNumbers: Bool {
    didSet { defaults.set(showsWeekNumbers, forKey: Key.showsWeekNumbers) }
  }
  public var showsFullDate: Bool {
    didSet { defaults.set(showsFullDate, forKey: Key.showsFullDate) }
  }
  public var highlightsWeekends: Bool {
    didSet { defaults.set(highlightsWeekends, forKey: Key.highlightsWeekends) }
  }
  public var reopenBehavior: ReopenBehavior {
    didSet { defaults.set(reopenBehavior.rawValue, forKey: Key.reopenBehavior) }
  }
  public var lastViewedMonth: Date? {
    didSet {
      if let lastViewedMonth {
        defaults.set(lastViewedMonth.timeIntervalSinceReferenceDate, forKey: Key.lastViewedMonth)
      } else {
        defaults.removeObject(forKey: Key.lastViewedMonth)
      }
    }
  }
  public var appearance: AppearancePreference {
    didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) }
  }
  public var density: Density {
    didSet { defaults.set(density.rawValue, forKey: Key.density) }
  }
  public var usesCustomAccent: Bool {
    didSet { defaults.set(usesCustomAccent, forKey: Key.usesCustomAccent) }
  }
  public var customAccent: AccentComponents {
    didSet { defaults.set([customAccent.red, customAccent.green, customAccent.blue], forKey: Key.customAccent) }
  }
  public var checksForUpdatesAutomatically: Bool {
    didSet { defaults.set(checksForUpdatesAutomatically, forKey: Key.checksForUpdates) }
  }

  /// The global shortcut that opens the panel. Nil means none is assigned, which is the default.
  public var hotkey: Hotkey? {
    didSet {
      if let hotkey {
        defaults.set(hotkey.storedValue, forKey: Key.hotkey)
      } else {
        defaults.removeObject(forKey: Key.hotkey)
      }
    }
  }

  /// Reads what is stored and falls back, key by key, to the default for anything missing or
  /// unreadable. A first launch and a value written by a newer version look the same here.
  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults

    func stored<T: RawRepresentable>(_ key: String, _ fallback: T) -> T where T.RawValue == String {
      defaults.string(forKey: key).flatMap { T(rawValue: $0) } ?? fallback
    }
    func flag(_ key: String, _ fallback: Bool) -> Bool {
      defaults.object(forKey: key) as? Bool ?? fallback
    }

    // A hand written pattern that no longer validates gives way to the last one that did, and
    // only when there is none to a preset: the menu bar never shows an empty or broken item.
    let presetValue = defaults.string(forKey: Key.formatPreset)
    let custom = defaults.string(forKey: Key.customPattern) ?? ""
    let storedLastValid = defaults.string(forKey: Key.lastValidPattern) ?? ""
    let lastValid = FormatValidator.isValid(storedLastValid) ? storedLastValid : ""
    if presetValue == Self.customPresetMarker, FormatValidator.isValid(custom) {
      formatPreset = nil
      customPattern = custom
    } else if presetValue == Self.customPresetMarker, !lastValid.isEmpty {
      formatPreset = nil
      customPattern = lastValid
    } else {
      formatPreset = presetValue.flatMap { FormatPreset(rawValue: $0) } ?? .dateAndWeekday
      customPattern = custom
    }
    lastValidPattern = lastValid

    menuBarIcon = stored(Key.menuBarIcon, MenuBarIcon.none)
    firstWeekday = stored(Key.firstWeekday, FirstWeekdayPreference.system)
    showsWeekNumbers = flag(Key.showsWeekNumbers, false)
    showsFullDate = flag(Key.showsFullDate, true)
    highlightsWeekends = flag(Key.highlightsWeekends, true)
    reopenBehavior = stored(Key.reopenBehavior, ReopenBehavior.currentMonth)
    lastViewedMonth = (defaults.object(forKey: Key.lastViewedMonth) as? Double)
      .map { Date(timeIntervalSinceReferenceDate: $0) }
    appearance = stored(Key.appearance, AppearancePreference.system)
    density = stored(Key.density, Density.regular)
    usesCustomAccent = flag(Key.usesCustomAccent, false)
    if let parts = defaults.array(forKey: Key.customAccent) as? [Double], parts.count == 3,
      parts.allSatisfy({ (0...1).contains($0) })
    {
      customAccent = AccentComponents(red: parts[0], green: parts[1], blue: parts[2])
    } else {
      customAccent = AccentComponents(red: 0, green: 0.478, blue: 1)
    }
    checksForUpdatesAutomatically = flag(Key.checksForUpdates, true)
    hotkey = (defaults.array(forKey: Key.hotkey) as? [Int]).flatMap { Hotkey(storedValue: $0) }
  }

  /// The pattern the menu bar shows: the preset resolved for the locale, or the hand written one.
  public func menuBarPattern(locale: Locale) -> String {
    formatPreset?.pattern(locale: locale) ?? customPattern
  }

  /// The pattern to show when `menuBarPattern` turns out to be invalid.
  public func fallbackPattern(locale: Locale) -> String {
    lastValidPattern.isEmpty ? FormatPreset.dateAndWeekday.pattern(locale: locale) : lastValidPattern
  }
}
