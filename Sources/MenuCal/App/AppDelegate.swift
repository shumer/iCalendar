import AppKit
import MenuCalCore
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private var statusItemController: StatusItemController?
  private var panelController: PanelController?
  private var settingsWindowController: SettingsWindowController?
  private var calendarModel: CalendarViewModel?
  private var systemObserver: SystemChangeObserver?
  private let loginItem = LoginItemModel()
  private let preferences = Preferences()

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.make(target: self)

    let model = CalendarViewModel(preferences: preferences)
    let panel = PanelController(content: CalendarPanelView(model: model))
    let status = StatusItemController(preferences: preferences)

    panel.onVisibilityChange = { [weak status] isOpen in
      status?.setHighlighted(isOpen)
      if !isOpen { model.didClose() }
    }
    panel.onKey = { event in
      model.handleKey(event, isRightToLeft: NSApp.userInterfaceLayoutDirection == .rightToLeft)
    }
    panel.onScroll = { event in
      model.handleScroll(event, isRightToLeft: NSApp.userInterfaceLayoutDirection == .rightToLeft)
    }
    status.onLeftClick = { [weak panel] button in
      guard let panel else { return }
      if !panel.isOpen { model.prepareToOpen() }
      panel.metrics = model.metrics
      panel.toggle(under: button, size: model.panelSize)
    }
    status.onOpenSettings = { [weak self] in self?.showSettings(nil) }
    status.onOpenAbout = { [weak self] in self?.showAbout(nil) }

    systemObserver = SystemChangeObserver { [weak status] in
      status?.systemChanged()
      model.systemChanged()
    }

    panelController = panel
    statusItemController = status
    calendarModel = model
    trackLayout()
    Log.app.info("MenuCal launched")
  }

  /// Settings that change the panel's size or the grid apply while the panel is open.
  private func trackLayout() {
    guard let model = calendarModel else { return }
    withObservationTracking {
      _ = model.panelSize
      _ = model.preferences.firstWeekday
    } onChange: { [weak self] in
      Task { @MainActor in
        guard let self, let model = self.calendarModel else { return }
        model.preferencesChanged()
        self.panelController?.metrics = model.metrics
        self.panelController?.resize(to: model.panelSize)
        self.trackLayout()
      }
    }
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
