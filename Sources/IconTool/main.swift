import CoreGraphics
import Foundation
import ImageIO
import RoostKit
import UniformTypeIdentifiers

let outputDirectory = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Roost.iconset"
try? FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)

let sizes: [(name: String, pixels: Int)] = [
  ("icon_16x16", 16), ("icon_16x16@2x", 32),
  ("icon_32x32", 32), ("icon_32x32@2x", 64),
  ("icon_128x128", 128), ("icon_128x128@2x", 256),
  ("icon_256x256", 256), ("icon_256x256@2x", 512),
  ("icon_512x512", 512), ("icon_512x512@2x", 1024)
]

for size in sizes {
  guard let context = CGContext(
    data: nil,
    width: size.pixels,
    height: size.pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { continue }

  IconArtwork.drawAppIcon(in: context, side: CGFloat(size.pixels))

  guard let image = context.makeImage() else { continue }
  let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(size.name + ".png")
  guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
  CGImageDestinationAddImage(destination, image, nil)
  CGImageDestinationFinalize(destination)
}

func writeGlyphPreview(named name: String, pixels: Int, background: CGColor?) {
  guard let context = CGContext(
    data: nil,
    width: pixels,
    height: pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { return }
  let bounds = CGRect(x: 0, y: 0, width: pixels, height: pixels)
  if let background {
    context.setFillColor(background)
    context.fill(bounds)
  }
  IconArtwork.drawMenuBarGlyph(in: context, bounds: bounds.insetBy(dx: CGFloat(pixels) * 0.12, dy: CGFloat(pixels) * 0.12))
  guard let image = context.makeImage() else { return }
  let url = URL(fileURLWithPath: outputDirectory).appendingPathComponent(name)
  guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
  CGImageDestinationAddImage(destination, image, nil)
  CGImageDestinationFinalize(destination)
}

writeGlyphPreview(named: "glyph-on-light.png", pixels: 44, background: CGColor(gray: 0.93, alpha: 1))
writeGlyphPreview(named: "glyph-on-dark.png", pixels: 44, background: CGColor(gray: 0.15, alpha: 1))

print("Wrote iconset to \(outputDirectory)")
