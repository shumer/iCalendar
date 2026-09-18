import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItemController: StatusItemController?
  private var panelController: PanelController?
  private var settingsWindowController: SettingsWindowController?
  private let loginItem = LoginItemModel()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.make(target: self)

    let panel = PanelController(content: CalendarPanelView())
    let status = StatusItemController()

    panel.onVisibilityChange = { [weak status] isOpen in
      status?.setHighlighted(isOpen)
    }
    status.onLeftClick = { [weak panel] button in
      guard let panel else { return }
      let size = panel.metrics.panelSize(showsWeekNumbers: false, showsFooter: true)
      panel.toggle(under: button, size: size)
    }
    status.onOpenSettings = { [weak self] in self?.showSettings(nil) }
    status.onOpenAbout = { [weak self] in self?.showAbout(nil) }

    panelController = panel
    statusItemController = status
    Log.app.info("MenuCal launched")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  @objc func showSettings(_ sender: Any?) {
    panelController?.close()
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(loginItem: loginItem)
    }
    loginItem.refresh()
    settingsWindowController?.showWindow(nil)
    bringToFront(settingsWindowController?.window)
  }

  @objc func showAbout(_ sender: Any?) {
    panelController?.close()
    NSApp.orderFrontStandardAboutPanel(nil)
    bringToFront(NSApp.windows.first { $0.isVisible && $0 !== settingsWindowController?.window && $0.canBecomeMain })
  }

  /// Activation is cooperative since macOS 14, and an agent app asking for it can be refused, so
  /// the window is also ordered front by itself. Otherwise it opens behind the frontmost app.
  private func bringToFront(_ window: NSWindow?) {
    NSApp.activate()
    window?.orderFrontRegardless()
    window?.makeKey()
  }
}
