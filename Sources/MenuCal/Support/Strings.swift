import Foundation
import Observation

/// Picks the string table at run time rather than once at launch, so a change of the system
/// language reaches the app without a restart. Views that call `L` read `revision` on the way,
/// which is what makes SwiftUI draw them again when the language changes.
@MainActor
@Observable
final class Localization {
  static let shared = Localization()

  private(set) var revision = 0
  @ObservationIgnored private var bundle: Bundle = .main

  private init() {
    bundle = Self.resolveBundle()
  }

  func reload() {
    let fresh = Self.resolveBundle()
    guard fresh.bundlePath != bundle.bundlePath else { return }
    bundle = fresh
    revision += 1
  }

  func string(_ key: String) -> String {
    _ = revision
    return bundle.localizedString(forKey: key, value: nil, table: nil)
  }

  private static func resolveBundle() -> Bundle {
    let available = Bundle.main.localizations.filter { $0 != "Base" }
    let preferred = Bundle.preferredLocalizations(from: available, forPreferences: Locale.preferredLanguages)
    guard let language = preferred.first,
      let path = Bundle.main.path(forResource: language, ofType: "lproj"),
      let bundle = Bundle(path: path)
    else { return .main }
    return bundle
  }
}

/// Every word on screen is a key in `Localizable.strings`, never a literal.
@MainActor
func L(_ key: String) -> String {
  Localization.shared.string(key)
}

@MainActor
func L(_ key: String, _ arguments: CVarArg...) -> String {
  String(format: L(key), locale: .autoupdatingCurrent, arguments: arguments)
}
