import Foundation

/// The modifier keys of a global shortcut, independent of AppKit and Carbon so that it can be
/// stored and tested in the core.
public struct HotkeyModifiers: OptionSet, Hashable, Sendable {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  public static let control = HotkeyModifiers(rawValue: 1 << 0)
  public static let option = HotkeyModifiers(rawValue: 1 << 1)
  public static let shift = HotkeyModifiers(rawValue: 1 << 2)
  public static let command = HotkeyModifiers(rawValue: 1 << 3)

  /// The order macOS writes them in: control, option, shift, command.
  public var symbols: String {
    var text = ""
    if contains(.control) { text += "⌃" }
    if contains(.option) { text += "⌥" }
    if contains(.shift) { text += "⇧" }
    if contains(.command) { text += "⌘" }
    return text
  }
}

/// A global shortcut: a virtual key code and its modifiers.
public struct Hotkey: Hashable, Sendable {
  public let keyCode: Int
  public let modifiers: HotkeyModifiers

  public init(keyCode: Int, modifiers: HotkeyModifiers) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  /// Virtual key codes of F1 to F20, which are usable as a shortcut on their own.
  static let functionKeys: Set<Int> = [
    122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111, 105, 107, 113, 106, 64, 79, 80, 90,
  ]

  /// A global shortcut must not swallow ordinary typing, so a letter needs Command, Option or
  /// Control with it. Shift alone is still typing.
  public var isUsable: Bool {
    if Self.functionKeys.contains(keyCode) { return true }
    return !modifiers.intersection([.command, .option, .control]).isEmpty
  }

  // MARK: Storage

  public var storedValue: [Int] { [keyCode, modifiers.rawValue] }

  public init?(storedValue: [Int]) {
    guard storedValue.count == 2, (0...0xFFFF).contains(storedValue[0]),
      (0...0b1111).contains(storedValue[1])
    else { return nil }
    let candidate = Hotkey(keyCode: storedValue[0], modifiers: HotkeyModifiers(rawValue: storedValue[1]))
    guard candidate.isUsable else { return nil }
    self = candidate
  }
}
