import AppKit

public enum LayoutCapturer {
  public static func captureCurrentLayout() -> Layout {
    let displays = DisplayGeometry.currentDisplays()
    let snapshots = WindowCatalog.allWindows()
      .filter { $0.isRestorable }
      .compactMap { snapshot($0, among: displays) }
    return Layout(
      displayFingerprint: DisplayFingerprint.fingerprint(of: displays),
      savedAt: Date(),
      windows: snapshots,
      displays: displays
    )
  }

  private static func snapshot(_ window: AppWindow, among displays: [DisplaySnapshot]) -> WindowSnapshot? {
    guard let bundleID = window.app.bundleIdentifier else { return nil }
    let frame = window.frame
    return WindowSnapshot(
      appBundleID: bundleID,
      appName: window.app.localizedName ?? bundleID,
      title: window.title,
      frame: FrameSnapshot(frame),
      isMinimized: window.isMinimized,
      isFullScreen: window.isFullScreen,
      displayKey: DisplayGeometry.display(containing: frame, among: displays)?.key
    )
  }
}
