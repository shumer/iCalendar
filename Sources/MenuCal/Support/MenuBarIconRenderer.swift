import AppKit
import MenuCalCore

/// The optional icon of the status item. Both variants are template images, so the system
/// tints them for a light or dark menu bar and inverts them while the item is highlighted.
@MainActor
enum MenuBarIconRenderer {
  static func image(for icon: MenuBarIcon, dayNumber: String) -> NSImage? {
    switch icon {
    case .none:
      return nil
    case .calendar:
      let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
      return NSImage(systemSymbolName: "calendar", accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
        .map { template($0) }
    case .dayNumber:
      return template(dayNumberImage(dayNumber))
    }
  }

  /// The gap a status bar button leaves between its image and its title.
  private static let buttonGap: CGFloat = 2

  /// A button gives no control over the gap between its image and its title, so the rest of the
  /// 4 pt the DesignSpec asks for is transparent space at the trailing edge of the image.
  private static func template(_ source: NSImage) -> NSImage {
    let padding = max(Tokens.MenuBar.iconTextGap - buttonGap, 0)
    let size = NSSize(width: source.size.width + padding, height: source.size.height)
    let padded = NSImage(size: size, flipped: false) { rect in
      let isRightToLeft = NSApp.userInterfaceLayoutDirection == .rightToLeft
      source.draw(in: NSRect(origin: NSPoint(x: isRightToLeft ? padding : 0, y: 0), size: source.size))
      return true
    }
    padded.isTemplate = true
    return padded
  }

  /// A calendar leaf outline with today's number inside, drawn rather than shipped so the digits
  /// can be the locale's own.
  private static func dayNumberImage(_ text: String) -> NSImage {
    let size = NSSize(width: 18, height: 16)
    let image = NSImage(size: size, flipped: false) { rect in
      NSColor.black.setStroke()
      let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.65, dy: 0.65), xRadius: 3.6, yRadius: 3.6)
      outline.lineWidth = 1.3
      outline.stroke()

      let band = NSBezierPath()
      band.move(to: NSPoint(x: 1, y: rect.maxY - 4.6))
      band.line(to: NSPoint(x: rect.maxX - 1, y: rect.maxY - 4.6))
      band.lineWidth = 1.3
      band.stroke()

      let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .bold),
        .foregroundColor: NSColor.black,
      ]
      let label = NSAttributedString(string: text, attributes: attributes)
      let labelSize = label.size()
      label.draw(at: NSPoint(x: (rect.width - labelSize.width) / 2, y: (rect.maxY - 4.6 - labelSize.height) / 2 + 0.3))
      return true
    }
    return image
  }
}
