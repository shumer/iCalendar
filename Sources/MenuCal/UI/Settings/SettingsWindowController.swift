import AppKit
import MenuCalCore
import SwiftUI

/// The settings window: AppKit's toolbar style tab controller with a SwiftUI pane per tab, which
/// is the system Settings look and can be opened from an AppKit menu in an agent app.
@MainActor
final class SettingsWindowController: NSWindowController {
  /// In the order of the tabs.
  enum Pane: Int {
    case general, calendar, events, appearance, about
  }

  private let tabs = SettingsTabViewController()

  init(
    preferences: Preferences, format: FormatEditorModel, hotkey: HotkeyRecorderModel,
    loginItem: LoginItemModel, updater: Updater, vacations: VacationStore,
    events: EventStore, eventSettings: EventSettingsStore
  ) {
    tabs.tabStyle = .toolbar
    tabs.addTabViewItem(
      Self.tab(symbol: "gearshape", GeneralPane(preferences: preferences, format: format, hotkey: hotkey, loginItem: loginItem)))
    tabs.addTabViewItem(Self.tab(symbol: "calendar", CalendarPane(preferences: preferences)))
    tabs.addTabViewItem(
      Self.tab(
        symbol: "list.bullet.rectangle",
        EventsPane(events: events, store: eventSettings, vacations: vacations, preferences: preferences, sheets: EventsPaneModel())))
    tabs.addTabViewItem(Self.tab(symbol: "paintbrush", AppearancePane(preferences: preferences)))
    tabs.addTabViewItem(Self.tab(symbol: "info.circle", AboutPane(updater: updater)))

    let window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    window.center()
    window.setFrameAutosaveName("MenuCalSettings")
    super.init(window: window)
    relocalize()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  func select(_ pane: Pane) {
    tabs.selectedTabViewItemIndex = pane.rawValue
  }

  override func showWindow(_ sender: Any?) {
    super.showWindow(sender)
    tabs.scrollSelectedPaneToTop()
  }

  /// Tab labels are plain AppKit strings, so a language change has to be pushed into them.
  func relocalize() {
    // Spelled out rather than looped over key names, so the test that sweeps the sources for
    // localisation calls can match them against the string tables.
    let labels = [
      L("settings.general"), L("settings.calendar"), L("settings.events"), L("settings.appearance"),
      L("settings.about"),
    ]
    for (item, label) in zip(tabs.tabViewItems, labels) {
      item.label = label
      item.viewController?.title = label
    }
    if let selected = tabs.tabViewItems[safe: tabs.selectedTabViewItemIndex] {
      window?.title = selected.label
    }
  }

  private static func tab(symbol: String, _ pane: some View) -> NSTabViewItem {
    let controller = NSHostingController(rootView: pane)
    // A pane sizes the window to itself. The Events pane fixes its own height and scrolls
    // inside, which the sizing options read like any other size.
    controller.sizingOptions = [.preferredContentSize]
    let item = NSTabViewItem(viewController: controller)
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    return item
  }
}

/// Resizes the window to the pane that was selected, the way System Settings style windows do.
/// `NSTabViewController` switches the view and leaves the window at the first pane's size.
private final class SettingsTabViewController: NSTabViewController {
  override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
    super.tabView(tabView, didSelect: tabViewItem)
    guard let window = view.window, let controller = tabViewItem?.viewController else { return }
    window.title = tabViewItem?.label ?? window.title
    controller.view.layoutSubtreeIfNeeded()
    let content = controller.view.fittingSize
    let target = window.frameRect(forContentRect: NSRect(origin: .zero, size: content))
    var frame = window.frame
    frame.origin.y += frame.height - target.height
    frame.size = target.size
    window.setFrame(frame, display: true, animate: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
    scrollSelectedPaneToTop()
  }

  /// A pane that scrolls opens at its top. A table inside it takes the first focus and would
  /// otherwise scroll itself into view, so the top is restored once the layout has settled.
  func scrollSelectedPaneToTop() {
    guard let view = tabViewItems[safe: selectedTabViewItemIndex]?.viewController?.view else { return }
    DispatchQueue.main.async {
      for scrollView in Self.scrollViews(in: view) {
        guard let document = scrollView.documentView else { continue }
        let top = document.isFlipped ? 0 : max(0, document.bounds.height - scrollView.contentView.bounds.height)
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: top))
        scrollView.reflectScrolledClipView(scrollView.contentView)
      }
    }
  }

  private static func scrollViews(in view: NSView) -> [NSScrollView] {
    var result: [NSScrollView] = []
    if let scrollView = view as? NSScrollView {
      result.append(scrollView)
      // Nested scroll views, such as a table's, are that table's own business.
      return result
    }
    for subview in view.subviews { result += scrollViews(in: subview) }
    return result
  }
}

extension Array {
  fileprivate subscript(safe index: Int) -> Element? {
    indices.contains(index) ? self[index] : nil
  }
}
