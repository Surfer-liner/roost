import AppKit
import RoostKit

enum CommandActions {
  static func wantsToRun() -> Bool {
    CommandLine.arguments.contains("--save") || CommandLine.arguments.contains("--restore")
  }

  static func runAndExit() -> Never {
    guard AccessibilityPermission.isGranted else {
      complain("Roost needs Accessibility permission. Enable it in System Settings → Privacy & Security → Accessibility.")
      exit(1)
    }
    if CommandLine.arguments.contains("--save") {
      saveAndExit()
    }
    restoreAndExit()
  }

  private static func saveAndExit() -> Never {
    let layout = LayoutCapturer.captureCurrentLayout()
    LayoutStore().save(layout)
    print("Saved \(layout.windows.count) windows for this display setup.")
    exit(0)
  }

  private static func restoreAndExit() -> Never {
    guard let layout = LayoutStore().layout(for: DisplayFingerprint.current()) else {
      complain("Nothing saved for this display setup yet.")
      exit(1)
    }
    var placed = 0
    var total = 0
    var finished = false
    LayoutRestorer(layout: layout) { placedNow, totalNow in
      placed = placedNow
      total = totalNow
      finished = true
    }.restore()
    let deadline = Date().addingTimeInterval(90)
    while !finished && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    print("Restored \(placed)/\(total) windows.")
    exit(0)
  }

  private static func complain(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }
}
