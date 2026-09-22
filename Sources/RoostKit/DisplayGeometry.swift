import AppKit

public struct DisplaySnapshot: Codable, Equatable {
  public let key: String
  public let frame: FrameSnapshot

  init(key: String, frame: CGRect) {
    self.key = key
    self.frame = FrameSnapshot(frame)
  }
}

public enum DisplayGeometry {
  public static func currentDisplays() -> [DisplaySnapshot] {
    displays(fromCocoaFrames: NSScreen.screens.map { $0.frame })
  }

  static func displays(fromCocoaFrames frames: [CGRect]) -> [DisplaySnapshot] {
    guard let primary = frames.first(where: { $0.origin == .zero }) ?? frames.first else { return [] }
    var keyed = frames.map { frame in
      (key: bareKey(for: frame, primary: primary), frame: accessibilityRect(ofCocoaFrame: frame, primaryHeight: primary.height))
    }
    disambiguateDuplicateKeys(&keyed)
    return keyed.map { DisplaySnapshot(key: $0.key, frame: $0.frame) }
  }

  static func legacyDisplays(fromFingerprint fingerprint: String) -> [DisplaySnapshot] {
    displays(fromCocoaFrames: fingerprint.components(separatedBy: " + ").compactMap(cocoaFrame(fromLegacyToken:)))
  }

  static func display(containing frame: CGRect, among displays: [DisplaySnapshot]) -> DisplaySnapshot? {
    let center = CGPoint(x: frame.midX, y: frame.midY)
    return displays.first { $0.frame.rect.contains(center) }
  }

  static func relocate(_ frame: CGRect, from saved: DisplaySnapshot, to current: DisplaySnapshot) -> CGRect {
    CGRect(
      x: current.frame.x + (frame.minX - saved.frame.x),
      y: current.frame.y + (frame.minY - saved.frame.y),
      width: frame.width,
      height: frame.height
    )
  }

  private static func bareKey(for frame: CGRect, primary: CGRect) -> String {
    "\(Int(frame.width))x\(Int(frame.height)):\(side(of: frame, relativeTo: primary))"
  }

  private static func side(of frame: CGRect, relativeTo primary: CGRect) -> String {
    let center = CGPoint(x: frame.midX, y: frame.midY)
    if center.x < primary.minX { return "left" }
    if center.x > primary.maxX { return "right" }
    if center.y >= primary.maxY { return "above" }
    if center.y < primary.minY { return "below" }
    return "main"
  }

  private static func accessibilityRect(ofCocoaFrame frame: CGRect, primaryHeight: CGFloat) -> CGRect {
    CGRect(x: frame.minX, y: primaryHeight - (frame.minY + frame.height), width: frame.width, height: frame.height)
  }

  private static func disambiguateDuplicateKeys(_ keyed: inout [(key: String, frame: CGRect)]) {
    let howMany = Dictionary(grouping: keyed, by: { $0.key }).mapValues { $0.count }
    var ordinals: [String: Int] = [:]
    for index in keyed.indices.sorted(by: { keyed[$0].frame.minX < keyed[$1].frame.minX }) {
      let key = keyed[index].key
      guard howMany[key, default: 0] > 1 else { continue }
      ordinals[key, default: 0] += 1
      keyed[index].key = "\(key)#\(ordinals[key]!)"
    }
  }

  private static func cocoaFrame(fromLegacyToken token: String) -> CGRect? {
    let halves = token.split(separator: "@")
    guard halves.count == 2 else { return nil }
    let size = halves[0].split(separator: "x").compactMap { Double($0) }
    let origin = halves[1].split(separator: ",").compactMap { Double($0) }
    guard size.count == 2, origin.count == 2 else { return nil }
    return CGRect(x: origin[0], y: origin[1], width: size[0], height: size[1])
  }
}
