import AppKit
import MenuCalCore
import Observation
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  private let preferences = Preferences()
  private let loginItem = LoginItemModel()
  private let hotkeys = HotkeyCenter()
  private lazy var updater = Updater(preferences: preferences)
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

    let model = CalendarViewModel(preferences: preferences, holidays: HolidayStore())
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
    status.onCheckForUpdates = { [weak self] in self?.checkForUpdates(nil) }
    status.onInstallUpdate = { [weak self] in self?.installUpdate() }
    status.availableUpdate = { [weak self] in self?.updater.availableRelease?.version.description }

    hotkeys.onFire = { [weak self] in self?.togglePanel() }
    hotkeys.register(preferences.hotkey)
    hotkeyRecorder.register = { [hotkeys] in hotkeys.register($0) }

    systemObserver = SystemChangeObserver { [weak self] in self?.systemChanged() }

    panelController = panel
    statusItemController = status
    calendarModel = model
    trackLayout()
    trackAppearance()
    updater.start()
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
    // Waking up is one of these changes, and a Mac that slept for days is due for a check.
    updater.checkIfDue()
    NSApp.mainMenu = MainMenu.make(target: self)
    settingsWindowController?.relocalize()
  }

  // MARK: Windows

  @objc func showSettings(_ sender: Any?) {
    showSettings(pane: nil)
  }

  private func showSettings(pane: SettingsWindowController.Pane?) {
    panelController?.close()
    if settingsWindowController == nil {
      settingsWindowController = SettingsWindowController(
        preferences: preferences, format: formatEditor, hotkey: hotkeyRecorder, loginItem: loginItem,
        updater: updater)
    }
    loginItem.refresh()
    if let pane { settingsWindowController?.select(pane) }
    settingsWindowController?.showWindow(nil)
    bringToFront(settingsWindowController?.window)
  }

  /// The result of a check the user asked for has to be shown somewhere, and an agent app has no
  /// window of its own for it: the About pane shows the state of the updater.
  @objc func checkForUpdates(_ sender: Any?) {
    showSettings(pane: .about)
    Task { await updater.check(userInitiated: true) }
  }

  private func installUpdate() {
    showSettings(pane: .about)
    Task { await updater.install() }
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
