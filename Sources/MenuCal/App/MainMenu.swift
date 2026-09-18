import AppKit

/// An agent app never shows its main menu, but key equivalents are still routed through it:
/// without an Edit menu the settings text fields cannot paste, and Cmd+W closes nothing.
@MainActor
enum MainMenu {
  static func make(target: AppDelegate) -> NSMenu {
    let main = NSMenu()

    let app = NSMenu()
    app.addItem(item(L("menu.about"), #selector(AppDelegate.showAbout(_:)), target: target))
    app.addItem(item(L("menu.checkForUpdates"), #selector(AppDelegate.checkForUpdates(_:)), target: target))
    app.addItem(.separator())
    app.addItem(item(L("menu.settings"), #selector(AppDelegate.showSettings(_:)), key: ",", target: target))
    app.addItem(.separator())
    app.addItem(item(L("menu.quit"), #selector(NSApplication.terminate(_:)), key: "q"))
    main.addItem(submenu(app, title: "MenuCal"))

    let edit = NSMenu(title: L("menu.edit"))
    edit.addItem(item(L("menu.edit.undo"), Selector(("undo:")), key: "z"))
    edit.addItem(item(L("menu.edit.redo"), Selector(("redo:")), key: "Z"))
    edit.addItem(.separator())
    edit.addItem(item(L("menu.edit.cut"), #selector(NSText.cut(_:)), key: "x"))
    edit.addItem(item(L("menu.edit.copy"), #selector(NSText.copy(_:)), key: "c"))
    edit.addItem(item(L("menu.edit.paste"), #selector(NSText.paste(_:)), key: "v"))
    edit.addItem(item(L("menu.edit.selectAll"), #selector(NSText.selectAll(_:)), key: "a"))
    main.addItem(submenu(edit, title: edit.title))

    let window = NSMenu(title: L("menu.window"))
    window.addItem(item(L("menu.window.close"), #selector(NSWindow.performClose(_:)), key: "w"))
    window.addItem(item(L("menu.window.minimize"), #selector(NSWindow.performMiniaturize(_:)), key: "m"))
    main.addItem(submenu(window, title: window.title))
    NSApp.windowsMenu = window

    return main
  }

  private static func item(
    _ title: String, _ action: Selector, key: String = "", target: AnyObject? = nil
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.target = target
    return item
  }

  private static func submenu(_ menu: NSMenu, title: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.submenu = menu
    return item
  }
}
