import AppKit
import MenuCalCore
import Observation

/// Records the global shortcut: while recording, the next key press with Command, Option or
/// Control becomes the shortcut, Esc cancels and Delete clears.
@MainActor
@Observable
final class HotkeyRecorderModel {
  private let preferences: Preferences
  private(set) var isRecording = false
  private(set) var wasRefused = false
  @ObservationIgnored private var monitor: Any?
  /// Returns false when the system refused the combination.
  @ObservationIgnored var register: (Hotkey?) -> Bool = { _ in true }

  init(preferences: Preferences) {
    self.preferences = preferences
  }

  var hotkey: Hotkey? { preferences.hotkey }

  var title: String {
    if isRecording { return L("settings.hotkey.recording") }
    return preferences.hotkey?.displayString ?? L("settings.hotkey.record")
  }

  func toggleRecording() {
    isRecording ? stop() : start()
  }

  func clear() {
    stop()
    wasRefused = false
    preferences.hotkey = nil
    _ = register(nil)
  }

  private func start() {
    isRecording = true
    wasRefused = false
    // The shortcut being replaced must not fire while its successor is typed.
    _ = register(nil)
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      MainActor.assumeIsolated { self?.handle(event) }
      return nil
    }
  }

  private func stop() {
    if let monitor { NSEvent.removeMonitor(monitor) }
    monitor = nil
    guard isRecording else { return }
    isRecording = false
    _ = register(preferences.hotkey)
  }

  private func handle(_ event: NSEvent) {
    switch Int(event.keyCode) {
    case 53:  // Esc keeps what was there.
      stop()
    case 51, 117:  // Delete and forward delete clear it.
      clear()
    default:
      guard let candidate = Hotkey(event: event) else {
        NSSound.beep()
        return
      }
      isRecording = false
      if let monitor { NSEvent.removeMonitor(monitor) }
      monitor = nil
      if register(candidate) {
        preferences.hotkey = candidate
      } else {
        wasRefused = true
        _ = register(preferences.hotkey)
      }
    }
  }
}
