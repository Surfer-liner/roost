import AppKit

enum DisplayFingerprint {
  static func current() -> String {
    NSScreen.screens
      .map(describe)
      .sorted()
      .joined(separator: " + ")
  }

  private static func describe(_ screen: NSScreen) -> String {
    let frame = screen.frame
    return "\(Int(frame.width))x\(Int(frame.height))@\(Int(frame.origin.x)),\(Int(frame.origin.y))"
  }
}
