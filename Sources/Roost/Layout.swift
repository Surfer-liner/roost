import CoreGraphics
import Foundation

struct Layout: Codable {
  let displayFingerprint: String
  let savedAt: Date
  let windows: [WindowSnapshot]
}

struct WindowSnapshot: Codable, Equatable {
  let appBundleID: String
  let appName: String
  let title: String
  let frame: FrameSnapshot
}

struct FrameSnapshot: Codable, Equatable {
  let x: Double
  let y: Double
  let width: Double
  let height: Double

  init(_ rect: CGRect) {
    x = rect.origin.x
    y = rect.origin.y
    width = rect.size.width
    height = rect.size.height
  }

  var rect: CGRect {
    CGRect(x: x, y: y, width: width, height: height)
  }
}
