// Draws the app icon into Resources/AppIcon/MenuCal.iconset, every size at its own pixel size
// rather than resampled from the largest, so the small ones stay crisp.
//
// Usage: swift Scripts/make-icon.swift
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
  .appendingPathComponent("Resources/AppIcon/MenuCal.iconset")
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
  CGColor(
    srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
    blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func gradient(_ top: UInt32, _ bottom: UInt32) -> CGGradient {
  CGGradient(
    colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [color(top), color(bottom)] as CFArray,
    locations: [0, 1])!
}

func draw(pixels: Int) -> CGImage {
  let context = CGContext(
    data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  // Everything below is written for a 1024 canvas, Apple's icon grid: an 824 tile, centred.
  let scale = CGFloat(pixels) / 1024
  context.scaleBy(x: scale, y: scale)

  let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
  let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

  context.saveGState()
  context.setShadow(offset: CGSize(width: 0, height: -12 * scale), blur: 28 * scale, color: color(0x000000, 0.28))
  context.addPath(shape)
  context.setFillColor(color(0xFFFFFF))
  context.fillPath()
  context.restoreGState()

  context.saveGState()
  context.addPath(shape)
  context.clip()
  context.drawLinearGradient(
    gradient(0xFFFFFF, 0xE6EAF1), start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY),
    options: [])

  // The header band of a calendar leaf.
  let band = CGRect(x: tile.minX, y: tile.maxY - 236, width: tile.width, height: 236)
  context.saveGState()
  context.clip(to: band)
  context.drawLinearGradient(
    gradient(0x4A95FF, 0x0A62F5), start: CGPoint(x: 0, y: band.maxY), end: CGPoint(x: 0, y: band.minY),
    options: [])
  context.restoreGState()

  // The month as dots, one of them today: a filled circle, as in the app. Small sizes get fewer,
  // larger dots, because twelve dots in sixteen pixels are noise.
  let small = pixels <= 64
  let columns = small ? 3 : 4
  let rows = small ? 2 : 3
  let area = CGRect(x: tile.minX + 96, y: tile.minY + 84, width: tile.width - 192, height: tile.height - 236 - 150)
  let stepX = area.width / CGFloat(columns)
  let stepY = area.height / CGFloat(rows)
  let radius = min(stepX, stepY) * (small ? 0.34 : 0.30)
  let today = small ? (row: 0, column: 1) : (row: 1, column: 2)
  for row in 0..<rows {
    for column in 0..<columns {
      let center = CGPoint(
        x: area.minX + stepX * (CGFloat(column) + 0.5),
        y: area.maxY - stepY * (CGFloat(row) + 0.5))
      let isToday = row == today.row && column == today.column
      let dot = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
      context.setFillColor(isToday ? color(0x0A62F5) : color(0xC3C9D4))
      context.fillEllipse(in: isToday ? dot.insetBy(dx: -radius * 0.22, dy: -radius * 0.22) : dot)
    }
  }
  context.restoreGState()

  // A hairline rim keeps the white tile from dissolving into a white window.
  context.addPath(shape)
  context.setStrokeColor(color(0x000000, 0.10))
  context.setLineWidth(max(2, 1 / scale))
  context.strokePath()

  return context.makeImage()!
}

let sizes: [(name: String, pixels: Int)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for size in sizes {
  let url = output.appendingPathComponent("\(size.name).png")
  let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, draw(pixels: size.pixels), nil)
  guard CGImageDestinationFinalize(destination) else { fatalError("could not write \(url.path)") }
}
print("Wrote \(sizes.count) images to \(output.path)")
