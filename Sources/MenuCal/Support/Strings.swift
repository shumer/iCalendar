import Foundation

/// Every word on screen is a key in `Localizable.strings`, never a literal.
func L(_ key: String) -> String {
  Bundle.main.localizedString(forKey: key, value: nil, table: nil)
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
  String(format: L(key), locale: .autoupdatingCurrent, arguments: arguments)
}
