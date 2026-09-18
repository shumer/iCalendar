import AppKit
import SwiftUI

/// The settings window: AppKit's toolbar style tab controller with a SwiftUI pane per tab, which
/// is the system Settings look and can be opened from an AppKit menu in an agent app.
@MainActor
final class SettingsWindowController: NSWindowController {
  init(loginItem: LoginItemModel) {
    let tabs = NSTabViewController()
    tabs.tabStyle = .toolbar
    tabs.addTabViewItem(
      Self.tab(L("settings.general"), symbol: "gearshape", GeneralPane(loginItem: loginItem)))

    let window = NSWindow(contentViewController: tabs)
    window.styleMask = [.titled, .closable, .miniaturizable]
    window.toolbarStyle = .preference
    window.isReleasedWhenClosed = false
    window.center()
    window.setFrameAutosaveName("MenuCalSettings")
    super.init(window: window)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  private static func tab(_ title: String, symbol: String, _ pane: some View) -> NSTabViewItem {
    let controller = NSHostingController(rootView: pane)
    controller.title = title
    controller.sizingOptions = [.preferredContentSize]
    let item = NSTabViewItem(viewController: controller)
    item.label = title
    item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
    return item
  }
}
