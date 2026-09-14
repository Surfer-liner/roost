import AppKit

public enum LayoutCapturer {
  public static func captureCurrentLayout() -> Layout {
    let snapshots = WindowCatalog.allWindows()
      .filter { $0.isRestorable }
      .compactMap(snapshot)
    return Layout(
      displayFingerprint: DisplayFingerprint.current(),
      savedAt: Date(),
      windows: snapshots
    )
  }

  private static func snapshot(_ window: AppWindow) -> WindowSnapshot? {
    guard let bundleID = window.app.bundleIdentifier else { return nil }
    return WindowSnapshot(
      appBundleID: bundleID,
      appName: window.app.localizedName ?? bundleID,
      title: window.title,
      frame: FrameSnapshot(window.frame),
      isMinimized: window.isMinimized,
      isFullScreen: window.isFullScreen
    )
  }
}
