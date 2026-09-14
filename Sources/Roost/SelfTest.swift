import AppKit
import RoostKit

enum SelfTest {
  static func wantsToRun() -> Bool {
    CommandLine.arguments.contains("--selftest")
  }

  static func runAndExit() -> Never {
    var lines = ["ax trusted: \(AccessibilityPermission.isGranted)"]
    if AccessibilityPermission.isGranted {
      lines += TextEditDrills().runAll()
      lines += CalculatorDrills().runAll()
    }
    let report = lines.joined(separator: "\n") + "\n"
    try? report.write(toFile: reportPath(), atomically: true, encoding: .utf8)
    print(report)
    let failed = lines.contains { $0.hasPrefix("FAIL") }
    exit(failed || !AccessibilityPermission.isGranted ? 1 : 0)
  }

  private static func reportPath() -> String {
    let arguments = CommandLine.arguments
    guard let flag = arguments.firstIndex(of: "--selftest"), arguments.indices.contains(flag + 1) else {
      return NSTemporaryDirectory() + "roost-selftest.txt"
    }
    return arguments[flag + 1]
  }
}

class WindowDrills {
  var lines: [String] = []

  func spin(_ seconds: TimeInterval) {
    RunLoop.current.run(until: Date().addingTimeInterval(seconds))
  }

  func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if condition() { return true }
      spin(0.25)
    }
    return condition()
  }

  func check(_ name: String, _ passed: Bool, _ details: String = "") {
    lines.append("\(passed ? "PASS" : "FAIL") \(name)\(details.isEmpty ? "" : " — \(details)")")
  }

  func fact(_ text: String) {
    lines.append("fact: \(text)")
  }

  func runningApp(_ bundleID: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
  }

  func restorableWindows(_ bundleID: String) -> [AppWindow] {
    guard let app = runningApp(bundleID) else { return [] }
    return WindowCatalog.windows(of: app).filter { $0.isRestorable }
  }

  func windowTitled(_ bundleID: String, _ titlePart: String) -> AppWindow? {
    restorableWindows(bundleID).first { $0.title.contains(titlePart) }
  }

  func layoutOfOnly(_ bundleID: String) -> Layout {
    let everything = LayoutCapturer.captureCurrentLayout()
    return Layout(
      displayFingerprint: everything.displayFingerprint,
      savedAt: everything.savedAt,
      windows: everything.windows.filter { $0.appBundleID == bundleID }
    )
  }

  func restoreAndWait(_ layout: Layout) -> (placed: Int, total: Int) {
    var result = (placed: 0, total: 0)
    var finished = false
    LayoutRestorer(layout: layout) { placed, total in
      result = (placed, total)
      finished = true
    }.restore()
    _ = waitUntil(20) { finished }
    return result
  }

  func closeEnough(_ a: CGRect, _ b: CGRect) -> Bool {
    abs(a.origin.x - b.origin.x) < 5 && abs(a.origin.y - b.origin.y) < 5 &&
      abs(a.width - b.width) < 5 && abs(a.height - b.height) < 5
  }

  func openQuietly(_ appURL: URL) {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
  }

  func quitForGood(_ bundleID: String) {
    runningApp(bundleID)?.terminate()
    if !waitUntil(5, { self.runningApp(bundleID) == nil }) {
      runningApp(bundleID)?.forceTerminate()
    }
  }
}

final class TextEditDrills: WindowDrills {
  private let textEdit = "com.apple.TextEdit"

  func runAll() -> [String] {
    guard runningApp(textEdit) == nil else {
      lines.append("SKIP TextEdit drills — TextEdit is already running, not touching your documents")
      return lines
    }
    openScratchDocuments()
    guard waitUntil(15, { self.restorableWindows(self.textEdit).count >= 2 }) else {
      check("textedit scratch windows appear", false, "only \(restorableWindows(textEdit).count) showed up")
      quitForGood(textEdit)
      return lines
    }
    spin(1)
    movedWindowFliesBackHome()
    minimizedWindowIsPulledOutOfTheDock()
    windowSavedMinimizedReturnsToTheDock()
    quitAppGetsRelaunchedAndPlaced()
    quitForGood(textEdit)
    return lines
  }

  private func openScratchDocuments() {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: textEdit) else { return }
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
    let one = folder.appendingPathComponent("roost-nest-one.txt")
    let two = folder.appendingPathComponent("roost-nest-two.txt")
    try? "roost selftest".write(to: one, atomically: true, encoding: .utf8)
    try? "roost selftest".write(to: two, atomically: true, encoding: .utf8)
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.open([one, two], withApplicationAt: appURL, configuration: configuration)
  }

  private func movedWindowFliesBackHome() {
    let layout = layoutOfOnly(textEdit)
    guard let window = windowTitled(textEdit, "roost-nest-one"), let home = savedFrame(layout, "roost-nest-one") else {
      check("moved window flies back home", false, "scratch window went missing")
      return
    }
    window.move(to: home.offsetBy(dx: 240, dy: 140))
    spin(0.5)
    let outcome = restoreAndWait(layout)
    spin(0.5)
    let landed = windowTitled(textEdit, "roost-nest-one")?.frame ?? .zero
    check("moved window flies back home", closeEnough(landed, home), "landed \(landed), placed \(outcome.placed)/\(outcome.total)")
  }

  private func minimizedWindowIsPulledOutOfTheDock() {
    let layout = layoutOfOnly(textEdit)
    guard let window = windowTitled(textEdit, "roost-nest-one"), let home = savedFrame(layout, "roost-nest-one") else {
      check("minimized window is pulled out of the dock", false, "scratch window went missing")
      return
    }
    window.minimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-one")?.isMinimized == true }
    fact("minimized window stays listed: \(windowTitled(textEdit, "roost-nest-one") != nil), frame while minimized: \(windowTitled(textEdit, "roost-nest-one")?.frame ?? .zero)")
    let outcome = restoreAndWait(layout)
    spin(1)
    let after = windowTitled(textEdit, "roost-nest-one")
    let unminimized = after?.isMinimized == false
    let backHome = closeEnough(after?.frame ?? .zero, home)
    check("minimized window is pulled out of the dock", unminimized && backHome, "minimized=\(String(describing: after?.isMinimized)), frame=\(after?.frame ?? .zero), placed \(outcome.placed)/\(outcome.total)")
  }

  private func windowSavedMinimizedReturnsToTheDock() {
    guard let window = windowTitled(textEdit, "roost-nest-two") else {
      check("window saved minimized returns to the dock", false, "scratch window went missing")
      return
    }
    let home = window.frame
    window.minimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-two")?.isMinimized == true }
    let layout = layoutOfOnly(textEdit)
    fact("capture while minimized keeps home frame: \(closeEnough(savedFrame(layout, "roost-nest-two") ?? .zero, home)), captured \(savedFrame(layout, "roost-nest-two") ?? .zero) vs home \(home)")
    window.unminimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-two")?.isMinimized == false }
    windowTitled(textEdit, "roost-nest-two")?.move(to: home.offsetBy(dx: 200, dy: 100))
    spin(0.5)
    let outcome = restoreAndWait(layout)
    spin(1)
    let after = windowTitled(textEdit, "roost-nest-two")
    check("window saved minimized returns to the dock", after?.isMinimized == true, "minimized=\(String(describing: after?.isMinimized)), placed \(outcome.placed)/\(outcome.total)")
    after?.unminimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-two")?.isMinimized == false }
  }

  private func quitAppGetsRelaunchedAndPlaced() {
    let layout = layoutOfOnly(textEdit)
    quitForGood(textEdit)
    guard runningApp(textEdit) == nil else {
      check("quit app gets relaunched", false, "TextEdit refused to quit")
      return
    }
    let outcome = restoreAndWait(layout)
    let relaunched = runningApp(textEdit) != nil
    check("quit app gets relaunched", relaunched)
    fact("after quit+restore placed \(outcome.placed)/\(outcome.total), windows now: \(restorableWindows(textEdit).map { $0.title })")
    check("relaunched app gets windows placed again", outcome.placed >= 1, "placed \(outcome.placed)/\(outcome.total)")
    if let home = savedFrame(layout, "roost-nest-one"), let back = windowTitled(textEdit, "roost-nest-one") {
      check("relaunched window lands on its saved spot", closeEnough(back.frame, home), "landed \(back.frame) vs home \(home)")
    }
  }

  private func savedFrame(_ layout: Layout, _ titlePart: String) -> CGRect? {
    layout.windows.first { $0.title.contains(titlePart) }?.frame.rect
  }
}

final class CalculatorDrills: WindowDrills {
  private let calculator = "com.apple.calculator"

  func runAll() -> [String] {
    guard runningApp(calculator) == nil else {
      lines.append("SKIP Calculator drills — Calculator is already running, not touching it")
      return lines
    }
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: calculator) else {
      lines.append("SKIP Calculator drills — Calculator not found")
      return lines
    }
    openQuietly(appURL)
    guard waitUntil(15, { !self.restorableWindows(self.calculator).isEmpty }) else {
      check("calculator window appears", false)
      quitForGood(calculator)
      return lines
    }
    spin(1)
    closedWindowIsSummonedBack()
    quitForGood(calculator)
    return lines
  }

  private func closedWindowIsSummonedBack() {
    let layout = layoutOfOnly(calculator)
    guard let window = restorableWindows(calculator).first, let home = layout.windows.first?.frame.rect else {
      check("closed window is summoned back", false, "no calculator window to work with")
      return
    }
    window.close()
    let closed = waitUntil(5) { self.restorableWindows(self.calculator).isEmpty }
    fact("after close: windows=\(restorableWindows(calculator).count), app still running=\(runningApp(calculator) != nil)")
    guard closed, runningApp(calculator) != nil else {
      check("closed window is summoned back", false, "close drill could not set the stage")
      return
    }
    let outcome = restoreAndWait(layout)
    spin(1)
    let back = restorableWindows(calculator).first
    let landed = back?.frame ?? .zero
    check("closed window is summoned back", back != nil && outcome.placed == 1, "placed \(outcome.placed)/\(outcome.total)")
    if back != nil {
      check("summoned window lands on its saved spot", closeEnough(landed, home), "landed \(landed) vs home \(home)")
    }
  }
}
