import CoreGraphics
import Foundation

public struct Layout: Codable, Equatable {
  public let displayFingerprint: String
  public let savedAt: Date
  public let windows: [WindowSnapshot]
  public let displays: [DisplaySnapshot]

  public init(displayFingerprint: String, savedAt: Date, windows: [WindowSnapshot], displays: [DisplaySnapshot] = []) {
    self.displayFingerprint = displayFingerprint
    self.savedAt = savedAt
    self.windows = windows
    self.displays = displays
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    displayFingerprint = try values.decode(String.self, forKey: .displayFingerprint)
    savedAt = try values.decode(Date.self, forKey: .savedAt)
    windows = try values.decode([WindowSnapshot].self, forKey: .windows)
    displays = try values.decodeIfPresent([DisplaySnapshot].self, forKey: .displays) ?? []
  }

  public var displayKeys: Set<String> {
    Set(displays.map { $0.key })
  }
}

public struct WindowSnapshot: Codable, Equatable {
  public let appBundleID: String
  public let appName: String
  public let title: String
  public let frame: FrameSnapshot
  public let isMinimized: Bool
  public let isFullScreen: Bool
  public let displayKey: String?

  init(
    appBundleID: String,
    appName: String,
    title: String,
    frame: FrameSnapshot,
    isMinimized: Bool,
    isFullScreen: Bool = false,
    displayKey: String? = nil
  ) {
    self.appBundleID = appBundleID
    self.appName = appName
    self.title = title
    self.frame = frame
    self.isMinimized = isMinimized
    self.isFullScreen = isFullScreen
    self.displayKey = displayKey
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    appBundleID = try values.decode(String.self, forKey: .appBundleID)
    appName = try values.decode(String.self, forKey: .appName)
    title = try values.decode(String.self, forKey: .title)
    frame = try values.decode(FrameSnapshot.self, forKey: .frame)
    isMinimized = try values.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false
    isFullScreen = try values.decodeIfPresent(Bool.self, forKey: .isFullScreen) ?? false
    displayKey = try values.decodeIfPresent(String.self, forKey: .displayKey)
  }

  func placed(at rect: CGRect) -> WindowSnapshot {
    WindowSnapshot(appBundleID: appBundleID, appName: appName, title: title, frame: FrameSnapshot(rect), isMinimized: isMinimized, isFullScreen: isFullScreen, displayKey: displayKey)
  }

  func onDisplay(_ key: String?) -> WindowSnapshot {
    WindowSnapshot(appBundleID: appBundleID, appName: appName, title: title, frame: frame, isMinimized: isMinimized, isFullScreen: isFullScreen, displayKey: key)
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
