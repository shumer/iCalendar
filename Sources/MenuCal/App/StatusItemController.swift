import AppKit
import MenuCalCore
import Observation

/// Draws the menu bar item and keeps its text current. The text changes on a timer aligned to
/// the unit the format shows, so a date only format wakes the app once a day.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
  private let statusItem: NSStatusItem
  private let contextMenu = NSMenu()
  private let preferences: Preferences
  private var cache = FormatterCache(calendar: .current, locale: .autoupdatingCurrent)
  private var timer: Timer?
  private var lastTitle = ""
  private var lastIconKey = ""
  private var wantsHighlight = false
  private var mouseUpMonitor: Any?

  var button: NSStatusBarButton? { statusItem.button }

  var onLeftClick: ((NSStatusBarButton) -> Void)?
  var onOpenSettings: (() -> Void)?
  var onOpenAbout: (() -> Void)?

  init(preferences: Preferences) {
    self.preferences = preferences
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    super.init()

    statusItem.autosaveName = "MenuCalStatusItem"
    statusItem.behavior = []
    contextMenu.delegate = self

    if let button = statusItem.button {
      button.target = self
      button.action = #selector(clicked(_:))
      button.sendAction(on: [.leftMouseDown, .rightMouseDown])
      button.setAccessibilityLabel(L("statusItem.accessibilityLabel"))
    }

    mouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
      DispatchQueue.main.async {
        MainActor.assumeIsolated { self?.applyHighlight() }
      }
      return event
    }

    refresh()
    trackPreferences()
  }

  /// The locale, the time zone, the clock or the day changed: every cached formatter is stale.
  func systemChanged() {
    cache.reset(calendar: .current, locale: .autoupdatingCurrent)
    lastIconKey = ""
    statusItem.button?.setAccessibilityLabel(L("statusItem.accessibilityLabel"))
    refresh()
  }

  private func trackPreferences() {
    withObservationTracking {
      _ = preferences.formatPreset
      _ = preferences.customPattern
      _ = preferences.lastValidPattern
      _ = preferences.menuBarIcon
    } onChange: { [weak self] in
      Task { @MainActor in
        self?.refresh()
        self?.trackPreferences()
      }
    }
  }

  /// Keeps the button highlighted while the panel is open, the way system items do. The button
  /// drops its own highlight when the click that opened the panel ends, which is after the action
  /// returns, so the state is applied again once that click is over.
  func setHighlighted(_ highlighted: Bool) {
    wantsHighlight = highlighted
    statusItem.button?.highlight(highlighted)
    guard highlighted else { return }
    for delay in [0.0, 0.25] {
      DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
        MainActor.assumeIsolated { self?.applyHighlight() }
      }
    }
  }

  private func applyHighlight() {
    statusItem.button?.highlight(wantsHighlight)
  }

  // MARK: - Text

  private var pattern: String {
    let pattern = preferences.menuBarPattern(locale: cache.locale)
    return FormatValidator.isValid(pattern) ? pattern : preferences.fallbackPattern(locale: cache.locale)
  }

  private func refresh() {
    let now = Date()
    let title = MenuBarText.render(
      pattern: preferences.menuBarPattern(locale: cache.locale),
      fallbackPattern: preferences.fallbackPattern(locale: cache.locale),
      date: now, cache: cache)
    // The item's width follows its title, so the title is touched only when it changed.
    if title != lastTitle, let button = statusItem.button {
      button.attributedTitle = NSAttributedString(
        string: title, attributes: [.font: Tokens.MenuBar.font])
      lastTitle = title
    }
    refreshIcon(at: now)
    scheduleNextRefresh(after: now)
  }

  private func refreshIcon(at now: Date) {
    guard let button = statusItem.button else { return }
    let day = cache.string(from: now, pattern: "d")
    let key = "\(preferences.menuBarIcon.rawValue) \(day)"
    guard key != lastIconKey else { return }
    lastIconKey = key
    let image = MenuBarIconRenderer.image(for: preferences.menuBarIcon, dayNumber: day)
    button.image = image
    button.imagePosition = image == nil ? .noImage : .imageLeading
    button.imageHugsTitle = true
  }

  private func scheduleNextRefresh(after now: Date) {
    timer?.invalidate()
    let granularity = RefreshSchedule.granularity(ofPattern: pattern)
    let fireDate = RefreshSchedule.nextFire(
      after: now, granularity: granularity, calendar: cache.calendar)
    let next = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated { self?.refresh() }
    }
    next.tolerance = RefreshSchedule.tolerance(for: granularity)
    RunLoop.main.add(next, forMode: .common)
    timer = next
  }

  // MARK: - Clicks

  @objc private func clicked(_ sender: NSStatusBarButton) {
    let event = NSApp.currentEvent
    let isSecondary = event?.type == .rightMouseDown
      || event?.modifierFlags.contains(.control) == true
    if isSecondary {
      showContextMenu()
    } else {
      onLeftClick?(sender)
    }
  }

  private func showContextMenu() {
    // Assigning the menu only for the click keeps the left click free for the panel.
    statusItem.menu = contextMenu
    statusItem.button?.performClick(nil)
    statusItem.menu = nil
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    menu.removeAllItems()
    menu.addItem(item(L("menu.settings"), #selector(openSettings), key: ","))
    menu.addItem(item(L("menu.about"), #selector(openAbout)))
    menu.addItem(.separator())
    let quit = NSMenuItem(
      title: L("menu.quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    menu.addItem(quit)
  }

  private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = self
    return item
  }

  @objc private func openSettings() { onOpenSettings?() }
  @objc private func openAbout() { onOpenAbout?() }
}
