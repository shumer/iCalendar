import AppKit
import SwiftUI

/// A borderless panel that can take the keyboard without activating the app, so the arrows work
/// in the calendar while the frontmost app keeps its menu bar.
final class CalendarPanel: NSPanel {
  var onCancel: (() -> Void)?
  /// Asked before Esc closes the panel; true means Esc did something else instead.
  var onEscape: (() -> Bool)?
  /// Returns true when the key was handled.
  var onKey: ((NSEvent) -> Bool)?
  var onScroll: ((NSEvent) -> Void)?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { false }

  override func cancelOperation(_ sender: Any?) {
    if onEscape?() == true { return }
    onCancel?()
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      if onEscape?() != true { onCancel?() }
      return
    }
    // Keys that mean nothing here are dropped quietly; the default is the system beep.
    _ = onKey?(event)
  }

  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.contains(.command), onKey?(event) == true { return true }
    return super.performKeyEquivalent(with: event)
  }

  override func scrollWheel(with event: NSEvent) {
    onScroll?(event)
  }
}

/// Owns the calendar panel: where it opens, when it closes, how it fades. DesignSpec section 2
/// chose a borderless panel over NSPopover, so closing on an outside click and on Esc is ours.
@MainActor
final class PanelController {
  private let panel: CalendarPanel
  private let background: GlassBackgroundView
  private var eventMonitors: [Any] = []
  private var isClosing = false
  private weak var anchorButton: NSStatusBarButton?

  /// Called with the new state whenever the panel opens or closes.
  var onVisibilityChange: ((Bool) -> Void)?
  var onEscape: (() -> Bool)? {
    get { panel.onEscape }
    set { panel.onEscape = newValue }
  }
  var onKey: ((NSEvent) -> Bool)? {
    get { panel.onKey }
    set { panel.onKey = newValue }
  }
  var onScroll: ((NSEvent) -> Void)? {
    get { panel.onScroll }
    set { panel.onScroll = newValue }
  }

  var isOpen: Bool { panel.isVisible && !isClosing }

  var metrics: Metrics = .regular {
    didSet { background.cornerRadius = metrics.panelCornerRadius }
  }

  init(content: some View) {
    let hosting = NSHostingView(rootView: content)
    background = GlassBackgroundView(content: hosting, cornerRadius: Metrics.regular.panelCornerRadius)

    panel = CalendarPanel(
      contentRect: .zero,
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: true)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.hasShadow = true
    panel.level = .popUpMenu
    panel.collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary, .moveToActiveSpace]
    panel.isMovable = false
    panel.hidesOnDeactivate = false
    panel.animationBehavior = .none
    panel.contentView = background
    panel.onCancel = { [weak self] in self?.close() }

    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
    ) { [weak self] _ in
      // Cmd+Tab and Mission Control produce no click for the monitors to see.
      MainActor.assumeIsolated { self?.close() }
    }
  }

  func toggle(under button: NSStatusBarButton, size: CGSize) {
    if isOpen {
      close()
    } else {
      open(under: button, size: size)
    }
  }

  func open(under button: NSStatusBarButton, size: CGSize) {
    guard let anchorWindow = button.window else { return }
    anchorButton = button
    isClosing = false

    // Glass is drawn by the window server and cannot be scaled with its content, so the panel
    // fades in and settles down from the menu bar instead. Under Reduce Motion it only fades.
    let target = frame(for: size, under: anchorWindow)
    let rise = Motion.isReduced ? 0 : Motion.panelRise
    panel.setFrame(target.offsetBy(dx: 0, dy: rise), display: true)
    panel.alphaValue = 0
    panel.makeKeyAndOrderFront(nil)
    panel.invalidateShadow()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Motion.panelOpenDuration
      context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
      panel.animator().alphaValue = 1
      panel.animator().setFrame(target, display: true)
    }
    installMonitors()
    onVisibilityChange?(true)
  }

  func close() {
    guard isOpen else { return }
    isClosing = true
    removeMonitors()
    onVisibilityChange?(false)
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Motion.panelCloseDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeOut)
      panel.animator().alphaValue = 0
    } completionHandler: { [weak self] in
      MainActor.assumeIsolated {
        guard let self, self.isClosing else { return }
        self.panel.orderOut(nil)
        self.isClosing = false
      }
    }
  }

  /// Resizes an open panel in place, keeping it under the status item.
  func resize(to size: CGSize) {
    guard panel.isVisible, let anchorWindow = anchorButton?.window else { return }
    panel.setFrame(frame(for: size, under: anchorWindow), display: true)
    panel.invalidateShadow()
  }

  private func frame(for size: CGSize, under anchorWindow: NSWindow) -> NSRect {
    let anchor = anchorWindow.frame
    let visible = (anchorWindow.screen ?? NSScreen.main)?.visibleFrame ?? anchor
    let margin = Tokens.screenEdgeMargin
    var x = anchor.midX - size.width / 2
    x = min(max(x, visible.minX + margin), visible.maxX - margin - size.width)
    let y = min(anchor.minY, visible.maxY) - Tokens.menuBarGap - size.height
    return NSRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)
  }

  private func installMonitors() {
    removeMonitors()
    let mouseDown: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    if let global = NSEvent.addGlobalMonitorForEvents(matching: mouseDown, handler: { [weak self] _ in
      MainActor.assumeIsolated { self?.close() }
    }) {
      eventMonitors.append(global)
    }
    if let local = NSEvent.addLocalMonitorForEvents(matching: mouseDown, handler: { [weak self] event in
      MainActor.assumeIsolated {
        guard let self else { return }
        // A click on the status item is the toggle's business, not an outside click.
        let inside = event.window === self.panel || event.window === self.anchorButton?.window
        if !inside { self.close() }
      }
      return event
    }) {
      eventMonitors.append(local)
    }
  }

  private func removeMonitors() {
    eventMonitors.forEach(NSEvent.removeMonitor)
    eventMonitors.removeAll()
  }
}
