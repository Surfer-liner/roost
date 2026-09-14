import CoreGraphics

public enum IconArtwork {
  public static func drawAppIcon(in context: CGContext, side: CGFloat) {
    let bounds = CGRect(x: 0, y: 0, width: side, height: side)
    clipToSquircle(context, in: bounds)
    paintBackground(context, in: bounds)
    context.resetClip()
    let content = bounds.insetBy(dx: side * 0.29, dy: side * 0.29)
    drawWindowTiles(context, in: content, style: .colored)
  }

  public static func drawMenuBarGlyph(in context: CGContext, bounds: CGRect) {
    let side = min(bounds.width, bounds.height) * 0.94
    let content = CGRect(
      x: bounds.midX - side / 2,
      y: bounds.midY - side / 2,
      width: side,
      height: side
    )
    drawWindowTiles(context, in: content, style: .monochrome)
  }

  private enum TileStyle {
    case colored
    case monochrome
  }

  private static func clipToSquircle(_ context: CGContext, in bounds: CGRect) {
    let radius = bounds.width * 0.2237
    context.addPath(CGPath(roundedRect: bounds, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
  }

  private static func paintBackground(_ context: CGContext, in bounds: CGRect) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let top = CGColor(red: 0.27, green: 0.31, blue: 0.44, alpha: 1)
    let bottom = CGColor(red: 0.11, green: 0.12, blue: 0.17, alpha: 1)
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: [top, bottom] as CFArray, locations: [0, 1]) else { return }
    context.drawLinearGradient(
      gradient,
      start: CGPoint(x: bounds.minX, y: bounds.maxY),
      end: CGPoint(x: bounds.maxX, y: bounds.minY),
      options: []
    )
  }

  private static func drawWindowTiles(_ context: CGContext, in content: CGRect, style: TileStyle) {
    let corner = min(content.width, content.height) * 0.08

    func tile(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGPath {
      let rect = CGRect(
        x: content.minX + x * content.width,
        y: content.minY + y * content.height,
        width: width * content.width,
        height: height * content.height
      )
      return CGPath(roundedRect: rect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    }

    let sidebar = tile(0.00, 0.00, 0.30, 1.00)
    let lowerPane = tile(0.38, 0.00, 0.62, 0.46)
    let upperPane = tile(0.38, 0.54, 0.62, 0.46)

    switch style {
    case .monochrome:
      context.setFillColor(CGColor(gray: 0, alpha: 1))
      for path in [sidebar, upperPane, lowerPane] {
        context.addPath(path)
      }
      context.fillPath()
    case .colored:
      context.saveGState()
      context.setShadow(
        offset: CGSize(width: 0, height: -corner * 0.9),
        blur: corner * 2,
        color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.35)
      )
      context.setFillColor(CGColor(red: 0.97, green: 0.98, blue: 1, alpha: 1))
      context.addPath(sidebar)
      context.addPath(upperPane)
      context.fillPath()
      context.setFillColor(CGColor(red: 0.36, green: 0.62, blue: 0.98, alpha: 1))
      context.addPath(lowerPane)
      context.fillPath()
      context.restoreGState()
    }
  }
}
