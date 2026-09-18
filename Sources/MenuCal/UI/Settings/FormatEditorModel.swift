import AppKit
import MenuCalCore
import Observation

/// The format field of the General pane. The text the user is typing is kept here and not in
/// `Preferences`, because a half typed pattern is usually invalid and must not reach the menu
/// bar: the item keeps showing the last pattern that worked.
@MainActor
@Observable
final class FormatEditorModel {
  private let preferences: Preferences
  private(set) var text: String
  private(set) var error: FormatValidationError?
  private(set) var preview = ""
  @ObservationIgnored private var cache = FormatterCache(calendar: .current, locale: .autoupdatingCurrent)

  init(preferences: Preferences) {
    self.preferences = preferences
    text = preferences.menuBarPattern(locale: .autoupdatingCurrent)
    refreshPreview()
  }

  var selectedPreset: FormatPreset? { error == nil ? preferences.formatPreset : nil }

  func edit(_ newText: String) {
    guard newText != text else { return }
    text = newText
    switch FormatValidator.validate(newText) {
    case .success:
      error = nil
      // Typing exactly what a preset resolves to selects that preset again.
      let locale = Locale.autoupdatingCurrent
      preferences.formatPreset = FormatPreset.allCases.first { $0.pattern(locale: locale) == newText }
      preferences.customPattern = newText
      preferences.lastValidPattern = newText
    case .failure(let failure):
      error = failure
      preferences.formatPreset = nil
      preferences.customPattern = newText
    }
    refreshPreview()
  }

  func choose(_ preset: FormatPreset) {
    let pattern = preset.pattern(locale: .autoupdatingCurrent)
    text = pattern
    error = nil
    preferences.formatPreset = preset
    preferences.lastValidPattern = pattern
    refreshPreview()
  }

  /// The locale or the clock changed: a preset resolves to a different pattern now.
  func systemChanged() {
    cache.reset(calendar: .current, locale: .autoupdatingCurrent)
    if let preset = preferences.formatPreset, error == nil {
      text = preset.pattern(locale: .autoupdatingCurrent)
    }
    refreshPreview()
  }

  var errorMessage: String? {
    switch error {
    case nil: nil
    case .empty: L("settings.format.error.empty")
    case .unbalancedQuote: L("settings.format.error.quote")
    case .unsupportedField(let letter): L("settings.format.error.unsupported", String(letter))
    case .fieldTooLong(let letter): L("settings.format.error.tooLong", String(letter))
    }
  }

  func openClockSettings() {
    let pane = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension")
    if let pane, NSWorkspace.shared.open(pane) { return }
    NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
  }

  private func refreshPreview() {
    preview = MenuBarText.render(
      pattern: text, fallbackPattern: preferences.fallbackPattern(locale: cache.locale),
      date: Date(), cache: cache)
  }
}
