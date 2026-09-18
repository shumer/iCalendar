import AppKit
import MenuCalCore
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let preferences = Preferences()
  private let loginItem = LoginItemModel()
  private let hotkeys = HotkeyCenter()
  private lazy var formatEditor = FormatEditorModel(preferences: preferences)
  private lazy var hotkeyRecorder = HotkeyRecorderModel(preferences: preferences)

  private var statusItemController: StatusItemController?
  private var panelController: PanelController?
  private var settingsWindowController: SettingsWindowController?
  private var calendarModel: CalendarViewModel?
  private var systemObserver: SystemChangeObserver?

  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.mainMenu = MainMenu.make(target: self)
    applyAppearance()

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
    status.onLeftClick = { [weak self] _ in self?.togglePanel() }
    status.onOpenSettings = { [weak self] in self?.showSettings(nil) }
    status.onOpenAbout = { [weak self] in self?.showAbout(nil) }

    hotkeys.onFire = { [weak self] in self?.togglePanel() }
    hotkeys.register(preferences.hotkey)
    hotkeyRecorder.register = { [hotkeys] in hotkeys.register($0) }

    systemObserver = SystemChangeObserver { [weak self] in self?.systemChanged() }

    panelController = panel
    statusItemController = status
    calendarModel = model
    trackLayout()
    trackAppearance()
    Log.app.info("MenuCal launched")
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    false
  }

  // MARK: Panel

  private func togglePanel() {
    guard let panel = panelController, let model = calendarModel,
      let button = statusItemController?.button
    else { return }
    if !panel.isOpen { model.prepareToOpen() }
    panel.metrics = model.metrics
    panel.toggle(under: button, size: model.panelSize)
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

  // MARK: Appearance

  private func trackAppearance() {
    withObservationTracking {
      _ = preferences.appearance
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.applyAppearance()
        self?.trackAppearance()
      }
    }
  }

  /// Nil hands the choice back to the system, including its automatic switch at dusk.
  private func applyAppearance() {
    switch preferences.appearance {
    case .system: NSApp.appearance = nil
    case .light: NSApp.appearance = NSAppearance(named: .aqua)
    case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
    }
  }

  // MARK: System changes

  /// The locale, the language, the region, the time zone, the clock or the day changed, or the
  /// Mac woke up. Everything that shows a date or a word is refreshed; nothing needs a restart.
  private func systemChanged() {
    Localization.shared.reload()
    statusItemController?.systemChanged()
    calendarModel?.systemChanged()
    formatEditor.systemChanged()
    loginItem.refresh()
    NSApp.mainMenu = MainMenu.make(target: self)
    settingsWindowController?.relocalize()
  }

  // MARK: Windows

  @objc func showSettings(_ sender: Any?) {
    panelController?.close()
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(
        preferences: preferences, format: formatEditor, hotkey: hotkeyRecorder, loginItem: loginItem)
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
