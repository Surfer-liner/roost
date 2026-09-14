import CoreGraphics
import Foundation

public struct Layout: Codable, Equatable {
  public let displayFingerprint: String
  public let savedAt: Date
  public let windows: [WindowSnapshot]

  public init(displayFingerprint: String, savedAt: Date, windows: [WindowSnapshot]) {
    self.displayFingerprint = displayFingerprint
    self.savedAt = savedAt
    self.windows = windows
  }
}

public struct WindowSnapshot: Codable, Equatable {
  public let appBundleID: String
  public let appName: String
  public let title: String
  public let frame: FrameSnapshot
  public let isMinimized: Bool

  init(appBundleID: String, appName: String, title: String, frame: FrameSnapshot, isMinimized: Bool) {
    self.appBundleID = appBundleID
    self.appName = appName
    self.title = title
    self.frame = frame
    self.isMinimized = isMinimized
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    appBundleID = try values.decode(String.self, forKey: .appBundleID)
    appName = try values.decode(String.self, forKey: .appName)
    title = try values.decode(String.self, forKey: .title)
    frame = try values.decode(FrameSnapshot.self, forKey: .frame)
    isMinimized = try values.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false
  }
}

public struct FrameSnapshot: Codable, Equatable {
  public let x: Double
  public let y: Double
  public let width: Double
  public let height: Double

  init(_ rect: CGRect) {
    x = rect.origin.x
    y = rect.origin.y
    width = rect.size.width
    height = rect.size.height
  }

  public var rect: CGRect {
    CGRect(x: x, y: y, width: width, height: height)
  }
}
