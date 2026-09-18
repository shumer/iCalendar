import AppKit

/// The surface the calendar sits on: Liquid Glass on macOS 26 and later, the popover material on
/// 14 and 15, and an opaque window colour under Reduce Transparency. The content view is kept
/// across rebuilds, so an accessibility setting flipped while the panel is open just swaps the
/// surface underneath it.
@MainActor
final class GlassBackgroundView: NSView {
  private let content: NSView
  private var surface: NSView?
  private var observer: NSObjectProtocol?

  var cornerRadius: CGFloat {
    didSet { if cornerRadius != oldValue { rebuild() } }
  }

  init(content: NSView, cornerRadius: CGFloat) {
    self.content = content
    self.cornerRadius = cornerRadius
    super.init(frame: .zero)
    // The window is a rectangle and the surface is not. Whatever a surface draws outside its
    // rounded shape, glass draws a shadow of its own there, would show in the four corners as
    // pieces of a square, and the window shadow would then follow that square. Clipping the
    // content to the shape makes the window's alpha the shape, so the system draws its shadow
    // and its hairline rim around the rounded panel, as it does for menus.
    wantsLayer = true
    layer?.masksToBounds = true
    layer?.cornerCurve = .continuous
    layer?.cornerRadius = cornerRadius
    rebuild()
    observer = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
      object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.rebuild() }
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) is not used")
  }

  private func rebuild() {
    content.removeFromSuperview()
    surface?.removeFromSuperview()

    let workspace = NSWorkspace.shared
    let newSurface: NSView
    layer?.cornerRadius = cornerRadius
    if workspace.accessibilityDisplayShouldReduceTransparency {
      newSurface = Self.opaqueSurface(
        cornerRadius: cornerRadius, outlined: workspace.accessibilityDisplayShouldIncreaseContrast)
      embed(content, in: newSurface)
    } else if #available(macOS 26.0, *) {
      let glass = NSGlassEffectView()
      glass.cornerRadius = cornerRadius
      glass.contentView = content
      newSurface = glass
    } else {
      newSurface = Self.materialSurface(cornerRadius: cornerRadius)
      embed(content, in: newSurface)
    }

    newSurface.frame = bounds
    newSurface.autoresizingMask = [.width, .height]
    addSubview(newSurface)
    surface = newSurface
    window?.invalidateShadow()
  }

  private func embed(_ view: NSView, in parent: NSView) {
    view.frame = parent.bounds
    view.autoresizingMask = [.width, .height]
    parent.addSubview(view)
  }

  private static func opaqueSurface(cornerRadius: CGFloat, outlined: Bool) -> NSView {
    // NSBox resolves its dynamic fill colour again when the appearance changes, which a plain
    // layer background does not.
    let box = NSBox()
    box.boxType = .custom
    box.titlePosition = .noTitle
    box.contentViewMargins = .zero
    box.cornerRadius = cornerRadius
    box.fillColor = .windowBackgroundColor
    box.borderColor = .separatorColor
    box.borderWidth = outlined ? 1 : 0
    return box
  }

  private static func materialSurface(cornerRadius: CGFloat) -> NSView {
    let effect = NSVisualEffectView()
    effect.material = .popover
    effect.blendingMode = .behindWindow
    effect.state = .active
    // A layer mask does not clip the window server's blur; the mask image does.
    effect.maskImage = roundedMask(cornerRadius: cornerRadius)
    return effect
  }

  private static func roundedMask(cornerRadius: CGFloat) -> NSImage {
    let edge = cornerRadius * 2 + 1
    let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
      NSColor.black.setFill()
      NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
      return true
    }
    image.capInsets = NSEdgeInsets(
      top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
    image.resizingMode = .stretch
    return image
  }
}
