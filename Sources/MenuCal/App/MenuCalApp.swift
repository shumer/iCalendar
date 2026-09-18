import AppKit

/// An AppKit entry point rather than a SwiftUI `App`: the app is a status item and a panel, and
/// the settings window has to open from an AppKit menu, which the `Settings` scene does not allow.
@main
enum MenuCalApp {
  @MainActor
  static func main() {
    let application = NSApplication.shared
    let delegate = AppDelegate()
    application.delegate = delegate
    // LSUIElement already says this in the bundle; saying it again keeps `swift run` Dock-free.
    application.setActivationPolicy(.accessory)
    application.run()
  }
}
