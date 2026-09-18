import AppKit
import Carbon.HIToolbox
import MenuCalCore

/// Registers the one global shortcut through Carbon's hot key API, which is still the only one
/// that needs no accessibility permission. The package the brief names for this does not build
/// without Xcode, see docs/adr/0002-no-third-party-dependencies.md.
@MainActor
final class HotkeyCenter {
  var onFire: (() -> Void)?

  private var hotKeyRef: EventHotKeyRef?
  private var handlerRef: EventHandlerRef?
  private static let signature: OSType = 0x4D43_414C  // "MCAL"

  init() {
    var spec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let context = Unmanaged.passUnretained(self).toOpaque()
    InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else { return noErr }
        // Carbon delivers hot key events on the main run loop.
        MainActor.assumeIsolated {
          Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue().onFire?()
        }
        return noErr
      }, 1, &spec, context, &handlerRef)
  }

  /// Replaces the registered shortcut. Returns false when the system refused it, which happens
  /// when another app already owns the combination.
  @discardableResult
  func register(_ hotkey: Hotkey?) -> Bool {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    guard let hotkey else { return true }
    let identifier = EventHotKeyID(signature: Self.signature, id: 1)
    let status = RegisterEventHotKey(
      UInt32(hotkey.keyCode), Self.carbonFlags(hotkey.modifiers), identifier,
      GetApplicationEventTarget(), 0, &hotKeyRef)
    if status != noErr {
      Log.app.error("Hot key registration failed with status \(status)")
    }
    return status == noErr
  }

  private static func carbonFlags(_ modifiers: HotkeyModifiers) -> UInt32 {
    var flags = 0
    if modifiers.contains(.command) { flags |= cmdKey }
    if modifiers.contains(.option) { flags |= optionKey }
    if modifiers.contains(.control) { flags |= controlKey }
    if modifiers.contains(.shift) { flags |= shiftKey }
    return UInt32(flags)
  }
}

extension Hotkey {
  /// A shortcut from a key event, or nil when the event is not usable as one.
  init?(event: NSEvent) {
    var modifiers: HotkeyModifiers = []
    if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
    if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
    if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
    if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
    let candidate = Hotkey(keyCode: Int(event.keyCode), modifiers: modifiers)
    guard candidate.isUsable else { return nil }
    self = candidate
  }

  /// The shortcut the way macOS writes it in menus, for the current keyboard layout.
  @MainActor
  var displayString: String {
    modifiers.symbols + Self.keyName(keyCode)
  }

  private static let specialKeys: [Int: String] = [
    kVK_Space: "Space", kVK_Return: "↩", kVK_Tab: "⇥", kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
    kVK_Escape: "⎋", kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
    kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
    kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
    kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    kVK_F13: "F13", kVK_F14: "F14", kVK_F15: "F15", kVK_F16: "F16", kVK_F17: "F17",
    kVK_F18: "F18", kVK_F19: "F19", kVK_F20: "F20",
  ]

  @MainActor
  private static func keyName(_ keyCode: Int) -> String {
    if let special = specialKeys[keyCode] { return special }
    guard
      let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
      let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
    else { return "?" }
    let layoutData = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    var deadKeys: UInt32 = 0
    var length = 0
    var characters = [UniChar](repeating: 0, count: 4)
    let status = layoutData.withUnsafeBytes { bytes -> OSStatus in
      guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return -1 }
      return UCKeyTranslate(
        layout, UInt16(keyCode), UInt16(kUCKeyActionDisplay), 0, UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysBit), &deadKeys, characters.count, &length, &characters)
    }
    guard status == noErr, length > 0 else { return "?" }
    return String(utf16CodeUnits: characters, count: length).uppercased()
  }
}
