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
    guard !NSScreen.screens.isEmpty else {
      complain("No displays detected. Nothing saved.")
      exit(1)
    }
    let layout = LayoutCapturer.captureCurrentLayout()
    guard !layout.windows.isEmpty else {
      complain("No windows to save.")
      exit(1)
    }
    guard LayoutStore().save(layout) else {
      complain("Could not write the layout file.")
      exit(1)
    }
    print("Saved \(layout.windows.count) windows for these \(layout.displays.count) displays.")
    exit(0)
  }

  private static func restoreAndExit() -> Never {
    guard let choice = LayoutStore().bestLayout(for: DisplayGeometry.currentDisplays()) else {
      complain("Nothing saved yet.")
      exit(1)
    }
    switch choice.match {
    case .sameDisplays:
      print("Restoring \(choice.layout.windows.count) windows saved \(describe(choice.layout.savedAt)) for these displays.")
    case .differentDisplays:
      print("No layout for these displays; using the most recent one (\(choice.layout.windows.count) windows, saved \(describe(choice.layout.savedAt))).")
    }
    var report: RestoreReport?
    LayoutRestorer(layout: choice.layout) { finished in
      report = finished
    }.restore()
    let deadline = Date().addingTimeInterval(150)
    while report == nil && Date() < deadline {
      RunLoop.current.run(until: Date().addingTimeInterval(0.1))
    }
    guard let report else {
      complain("Restore did not finish in time.")
      exit(1)
    }
    print("Restored \(report.placed)/\(report.total) windows.")
    for line in report.leftBehind {
      print("  left behind — \(line)")
    }
    exit(report.everythingLanded ? 0 : 2)
  }

  private static func describe(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  private static func complain(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
  }
}
