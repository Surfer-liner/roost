import AppKit
import RoostKit

enum SelfTest {
  static func wantsToRun() -> Bool {
    mode() != nil
  }

  static func runAndExit() -> Never {
    guard let mode = mode() else { exit(0) }
    var lines = ["ax trusted: \(AccessibilityPermission.isGranted)"]
    if AccessibilityPermission.isGranted {
      switch mode {
      case .diagnose:
        lines += Diagnostics().dump()
      case .drills:
        lines += TextEditDrills().runAll()
        lines += CalculatorDrills().runAll()
      case .rehearse(let bundleID):
        lines += Rehearsal(bundleID: bundleID).run()
      case .relaunch(let bundleID):
        lines += RelaunchTest(bundleID: bundleID).run()
      case .counttest(let bundleID):
        lines += CountRestoreTest(bundleID: bundleID).run()
      case .summon(let bundleID):
        lines += SummonTest(bundleID: bundleID).run()
      case .dumpmenu(let bundleID):
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
          lines += WindowSummoner.dumpMenuBar(for: app)
        } else {
          lines.append("SKIP dumpmenu — \(bundleID) is not running")
        }
      }
    }
    let report = lines.joined(separator: "\n") + "\n"
    try? report.write(toFile: reportPath(), atomically: true, encoding: .utf8)
    print(report)
    let failed = lines.contains { $0.hasPrefix("FAIL") }
    exit(failed || !AccessibilityPermission.isGranted ? 1 : 0)
  }

  private enum Mode {
    case diagnose
    case drills
    case rehearse(String)
    case relaunch(String)
    case counttest(String)
    case summon(String)
    case dumpmenu(String)
  }

  private static func mode() -> Mode? {
    let arguments = CommandLine.arguments
    if arguments.contains("--diagnose") { return .diagnose }
    if arguments.contains("--selftest") { return .drills }
    if let flag = arguments.firstIndex(of: "--rehearse"), arguments.indices.contains(flag + 1) {
      return .rehearse(arguments[flag + 1])
    }
    if let flag = arguments.firstIndex(of: "--relaunch"), arguments.indices.contains(flag + 1) {
      return .relaunch(arguments[flag + 1])
    }
    if let flag = arguments.firstIndex(of: "--counttest"), arguments.indices.contains(flag + 1) {
      return .counttest(arguments[flag + 1])
    }
    if let flag = arguments.firstIndex(of: "--summon"), arguments.indices.contains(flag + 1) {
      return .summon(arguments[flag + 1])
    }
    if let flag = arguments.firstIndex(of: "--dumpmenu"), arguments.indices.contains(flag + 1) {
      return .dumpmenu(arguments[flag + 1])
    }
    return nil
  }

  private static func reportPath() -> String {
    let arguments = CommandLine.arguments
    if let flag = arguments.firstIndex(of: "--report"), arguments.indices.contains(flag + 1) {
      return arguments[flag + 1]
    }
    return NSTemporaryDirectory() + "roost-report.txt"
  }
}

final class Diagnostics {
  func dump() -> [String] {
    var lines = ["fingerprint: \(DisplayFingerprint.current())"]
    for (index, screen) in NSScreen.screens.enumerated() {
      lines.append("display \(index): frame=\(screen.frame) visible=\(screen.visibleFrame)")
    }
    for app in WindowCatalog.visibleApps().sorted(by: { ($0.localizedName ?? "") < ($1.localizedName ?? "") }) {
      let windows = WindowCatalog.windows(of: app)
      let restorable = windows.filter { $0.isRestorable }
      guard !windows.isEmpty else { continue }
      lines.append("app \(app.localizedName ?? "?") [\(app.bundleIdentifier ?? "?")] windows=\(windows.count) restorable=\(restorable.count)")
      for window in windows {
        lines.append("    window title='\(window.title)' standard=\(window.isStandard) minimized=\(window.isMinimized) frame=\(compact(window.frame))")
      }
    }
    return lines
  }

  private func compact(_ rect: CGRect) -> String {
    "(\(Int(rect.origin.x)),\(Int(rect.origin.y)) \(Int(rect.width))x\(Int(rect.height)))"
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

  func restoreAndWait(_ layout: Layout, timeout: TimeInterval = 40) -> (placed: Int, total: Int) {
    var result = (placed: 0, total: 0)
    var finished = false
    LayoutRestorer(layout: layout) { placed, total in
      result = (placed, total)
      finished = true
    }.restore()
    _ = waitUntil(timeout) { finished }
    return result
  }

  func settled(_ observed: CGRect, _ target: CGRect) -> Bool {
    Geometry.isSettled(observed, at: target)
  }

  func openQuietly(_ appURL: URL) {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
  }

  func launchAndWaitForWindow(_ bundleID: String, opening urls: [URL] = []) -> Bool {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return false }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    if urls.isEmpty {
      NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
    } else {
      NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: configuration)
    }
    return waitUntil(20) { !self.restorableWindows(bundleID).isEmpty }
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
    writeScratchDocuments()
    _ = launchAndWaitForWindow(textEdit, opening: scratchDocumentURLs())
    guard waitUntil(15, { self.restorableWindows(self.textEdit).count >= 2 }) else {
      check("textedit scratch windows appear", false, "only \(restorableWindows(textEdit).count) showed up")
      quitForGood(textEdit)
      return lines
    }
    spin(1)
    movedWindowFliesBackHome()
    windowThatFightsBackIsHeldInPlace()
    minimizedWindowIsPulledOutOfTheDock()
    windowSavedMinimizedReturnsToTheDock()
    closedWindowIsReopenedToHitTheSavedCount()
    quitAppGetsRelaunchedAndPlaced()
    quitForGood(textEdit)
    return lines
  }

  private func scratchDocumentURLs() -> [URL] {
    let folder = URL(fileURLWithPath: NSTemporaryDirectory())
    return [
      folder.appendingPathComponent("roost-nest-one.txt"),
      folder.appendingPathComponent("roost-nest-two.txt")
    ]
  }

  private func writeScratchDocuments() {
    for url in scratchDocumentURLs() {
      try? "roost selftest".write(to: url, atomically: true, encoding: .utf8)
    }
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
    check("moved window flies back home", settled(landed, home), "landed \(landed), placed \(outcome.placed)/\(outcome.total)")
  }

  private func windowThatFightsBackIsHeldInPlace() {
    let layout = layoutOfOnly(textEdit)
    guard let window = windowTitled(textEdit, "roost-nest-one"), let home = savedFrame(layout, "roost-nest-one") else {
      check("window that fights back is held in place", false, "scratch window went missing")
      return
    }
    let intruder = home.offsetBy(dx: 320, dy: 220)
    var shovesLeft = 6
    let heckler = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
      guard shovesLeft > 0 else { timer.invalidate(); return }
      shovesLeft -= 1
      self.windowTitled(self.textEdit, "roost-nest-one")?.move(to: intruder)
    }
    window.move(to: intruder)
    let outcome = restoreAndWait(layout)
    heckler.invalidate()
    spin(1.5)
    let landed = windowTitled(textEdit, "roost-nest-one")?.frame ?? .zero
    check("window that fights back is held in place", settled(landed, home), "landed \(landed) vs home \(home), placed \(outcome.placed)/\(outcome.total)")
  }

  private func minimizedWindowIsPulledOutOfTheDock() {
    let layout = layoutOfOnly(textEdit)
    guard let window = windowTitled(textEdit, "roost-nest-one"), let home = savedFrame(layout, "roost-nest-one") else {
      check("minimized window is pulled out of the dock", false, "scratch window went missing")
      return
    }
    window.minimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-one")?.isMinimized == true }
    let outcome = restoreAndWait(layout)
    spin(1)
    let after = windowTitled(textEdit, "roost-nest-one")
    let unminimized = after?.isMinimized == false
    let backHome = settled(after?.frame ?? .zero, home)
    check("minimized window is pulled out of the dock", unminimized && backHome, "minimized=\(String(describing: after?.isMinimized)), frame=\(after?.frame ?? .zero), placed \(outcome.placed)/\(outcome.total)")
  }

  private func windowSavedMinimizedReturnsToTheDock() {
    guard let window = windowTitled(textEdit, "roost-nest-two") else {
      check("window saved minimized returns to the dock", false, "scratch window went missing")
      return
    }
    window.minimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-two")?.isMinimized == true }
    let layout = layoutOfOnly(textEdit)
    window.unminimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-two")?.isMinimized == false }
    let outcome = restoreAndWait(layout)
    spin(1)
    let after = windowTitled(textEdit, "roost-nest-two")
    check("window saved minimized returns to the dock", after?.isMinimized == true, "minimized=\(String(describing: after?.isMinimized)), placed \(outcome.placed)/\(outcome.total)")
    after?.unminimize()
    _ = waitUntil(5) { self.windowTitled(self.textEdit, "roost-nest-two")?.isMinimized == false }
  }

  private func closedWindowIsReopenedToHitTheSavedCount() {
    let layout = layoutOfOnly(textEdit)
    let savedCount = layout.windows.count
    guard savedCount >= 2, let victim = windowTitled(textEdit, "roost-nest-two") else {
      check("closed window is reopened to hit the saved count", false, "need two scratch windows to run this")
      return
    }
    victim.close()
    _ = waitUntil(5) { self.restorableWindows(self.textEdit).count < savedCount }
    fact("after closing one: \(restorableWindows(textEdit).count) window(s) left of \(savedCount) saved")
    let outcome = restoreAndWait(layout)
    spin(1)
    let backTo = restorableWindows(textEdit).count
    check("closed window is reopened to hit the saved count", backTo >= savedCount, "back to \(backTo)/\(savedCount), placed \(outcome.placed)/\(outcome.total)")
  }

  private func quitAppGetsRelaunchedAndPlaced() {
    let layout = layoutOfOnly(textEdit)
    quitForGood(textEdit)
    guard runningApp(textEdit) == nil else {
      check("quit app gets relaunched", false, "TextEdit refused to quit")
      return
    }
    let outcome = restoreAndWait(layout)
    check("quit app gets relaunched", runningApp(textEdit) != nil)
    fact("after quit+restore placed \(outcome.placed)/\(outcome.total), windows now: \(restorableWindows(textEdit).map { $0.title })")
    check("relaunched app gets a window placed again", outcome.placed >= 1, "placed \(outcome.placed)/\(outcome.total)")
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
    guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: calculator) != nil else {
      lines.append("SKIP Calculator drills — Calculator not found")
      return lines
    }
    guard launchAndWaitForWindow(calculator) else {
      check("calculator window appears", false)
      quitForGood(calculator)
      return lines
    }
    spin(1)
    aSecondAppAlsoFliesHome()
    quitAndRelaunchBringsItBack()
    quitForGood(calculator)
    return lines
  }

  private func aSecondAppAlsoFliesHome() {
    let layout = layoutOfOnly(calculator)
    guard let window = restorableWindows(calculator).first, let home = layout.windows.first?.frame.rect else {
      check("a second app also flies home", false, "no calculator window to work with")
      return
    }
    window.move(to: home.offsetBy(dx: 200, dy: 160))
    spin(0.5)
    let outcome = restoreAndWait(layout)
    spin(0.5)
    let landed = restorableWindows(calculator).first?.frame ?? .zero
    check("a second app also flies home", settled(landed, home), "landed \(landed) vs home \(home), placed \(outcome.placed)/\(outcome.total)")
  }

  private func quitAndRelaunchBringsItBack() {
    let layout = layoutOfOnly(calculator)
    guard let home = layout.windows.first?.frame.rect else {
      check("quit-on-close app is relaunched and placed", false, "no calculator window to work with")
      return
    }
    quitForGood(calculator)
    guard runningApp(calculator) == nil else {
      check("quit-on-close app is relaunched and placed", false, "Calculator refused to quit")
      return
    }
    let outcome = restoreAndWait(layout, timeout: 60)
    spin(1)
    let landed = restorableWindows(calculator).first?.frame
    check("quit-on-close app is relaunched and placed", landed != nil && outcome.placed == 1, "placed \(outcome.placed)/\(outcome.total)")
    if let landed {
      check("relaunched second app lands on its saved spot", settled(landed, home), "landed \(landed) vs home \(home)")
    }
  }
}

final class RelaunchTest: WindowDrills {
  private let bundleID: String

  init(bundleID: String) {
    self.bundleID = bundleID
  }

  func run() -> [String] {
    let name = runningApp(bundleID)?.localizedName ?? bundleID
    guard runningApp(bundleID) != nil else {
      lines.append("SKIP relaunch test — \(bundleID) is not running")
      return lines
    }
    let layout = layoutOfOnly(bundleID)
    let visibleTargets = layout.windows.filter { !$0.isMinimized }
    guard !visibleTargets.isEmpty else {
      lines.append("SKIP relaunch test — \(name) has no visible window to relaunch")
      return lines
    }
    for window in layout.windows {
      fact("\(name): saved '\(window.title)' at \(compact(window.frame.rect))")
    }
    quitForGood(bundleID)
    guard runningApp(bundleID) == nil else {
      check("\(name): quits so restore has to relaunch it", false, "app refused to quit")
      return lines
    }
    fact("\(name): quit; restore now has to relaunch and place it")
    let outcome = restoreAndWait(layout, timeout: 90)
    spin(3)
    check("\(name): comes back after being quit", runningApp(bundleID) != nil)
    var landedRight = 0
    for saved in visibleTargets {
      guard let current = windowTitled(bundleID, saved.title) else {
        fact("    '\(saved.title)' did not come back")
        continue
      }
      if settled(current.frame, saved.frame.rect) {
        landedRight += 1
      } else {
        fact("    '\(saved.title)' landed at \(compact(current.frame)) instead of \(compact(saved.frame.rect))")
      }
    }
    check("\(name): relaunched window lands on its own monitor and stays", landedRight == visibleTargets.count, "\(landedRight)/\(visibleTargets.count) settled, placed \(outcome.placed)/\(outcome.total)")
    return lines
  }

  private func compact(_ rect: CGRect) -> String {
    "(\(Int(rect.origin.x)),\(Int(rect.origin.y)) \(Int(rect.width))x\(Int(rect.height)))"
  }
}

final class SummonTest: WindowDrills {
  private let bundleID: String

  init(bundleID: String) {
    self.bundleID = bundleID
  }

  func run() -> [String] {
    let name = runningApp(bundleID)?.localizedName ?? bundleID
    guard let app = runningApp(bundleID) else {
      lines.append("SKIP summon — \(bundleID) is not running")
      return lines
    }
    let before = restorableWindows(bundleID).count
    let pressed = WindowSummoner.requestOneMoreWindow(from: app)
    fact("\(name): menu item found and pressed = \(pressed)")
    let grew = waitUntil(8) { self.restorableWindows(self.bundleID).count > before }
    let after = restorableWindows(bundleID).count
    check("\(name): a fresh window can be summoned", grew, "windows \(before) → \(after)")
    return lines
  }
}

final class CountRestoreTest: WindowDrills {
  private let bundleID: String

  init(bundleID: String) {
    self.bundleID = bundleID
  }

  func run() -> [String] {
    let name = runningApp(bundleID)?.localizedName ?? bundleID
    let startWindows = restorableWindows(bundleID)
    guard startWindows.count >= 2 else {
      lines.append("SKIP count test — \(name) needs at least 2 open windows (has \(startWindows.count))")
      return lines
    }
    let layout = layoutOfOnly(bundleID)
    let saved = layout.windows.count
    fact("\(name): saved \(saved) windows")
    for window in startWindows.dropFirst() {
      window.close()
    }
    _ = waitUntil(6) { self.restorableWindows(self.bundleID).count <= 1 }
    fact("\(name): reduced to \(restorableWindows(bundleID).count) window(s), restore must rebuild to \(saved)")
    let outcome = restoreAndWait(layout, timeout: 60)
    spin(2)
    let finalCount = restorableWindows(bundleID).count
    check("\(name): window count is rebuilt", finalCount >= saved, "ended with \(finalCount)/\(saved), placed \(outcome.placed)/\(outcome.total)")
    var slotsCovered = 0
    for savedWindow in layout.windows where !savedWindow.isMinimized {
      if restorableWindows(bundleID).contains(where: { settled($0.frame, savedWindow.frame.rect) }) {
        slotsCovered += 1
      } else {
        fact("    no window landed on \(compact(savedWindow.frame.rect))")
      }
    }
    let visibleSlots = layout.windows.filter { !$0.isMinimized }.count
    check("\(name): every saved slot has a window on it", slotsCovered == visibleSlots, "\(slotsCovered)/\(visibleSlots) slots covered")
    return lines
  }

  private func compact(_ rect: CGRect) -> String {
    "(\(Int(rect.origin.x)),\(Int(rect.origin.y)) \(Int(rect.width))x\(Int(rect.height)))"
  }
}

final class Rehearsal: WindowDrills {
  private let bundleID: String

  init(bundleID: String) {
    self.bundleID = bundleID
  }

  func run() -> [String] {
    let name = runningApp(bundleID)?.localizedName ?? bundleID
    guard runningApp(bundleID) != nil else {
      lines.append("SKIP rehearsal — \(bundleID) is not running")
      return lines
    }
    let layout = layoutOfOnly(bundleID)
    guard !layout.windows.isEmpty else {
      lines.append("SKIP rehearsal — \(name) has no restorable windows right now")
      return lines
    }
    fact("\(name): rehearsing with \(layout.windows.count) window(s)")
    for window in layout.windows {
      fact("    saved '\(window.title)' at \(compact(window.frame.rect)) minimized=\(window.isMinimized)")
    }
    let originals = restorableWindows(bundleID)
    for window in originals {
      window.move(to: window.frame.offsetBy(dx: 260, dy: 180))
    }
    spin(0.6)
    let outcome = restoreAndWait(layout)
    spin(2)
    var landedRight = 0
    for saved in layout.windows where !saved.isMinimized {
      guard let current = windowTitled(bundleID, saved.title) else { continue }
      if settled(current.frame, saved.frame.rect) {
        landedRight += 1
      } else {
        fact("    '\(saved.title)' ended at \(compact(current.frame)) instead of \(compact(saved.frame.rect))")
      }
    }
    let visibleTargets = layout.windows.filter { !$0.isMinimized }.count
    check("\(name): every window returned home and stayed", landedRight == visibleTargets, "\(landedRight)/\(visibleTargets) settled, placed \(outcome.placed)/\(outcome.total)")
    return lines
  }

  private func compact(_ rect: CGRect) -> String {
    "(\(Int(rect.origin.x)),\(Int(rect.origin.y)) \(Int(rect.width))x\(Int(rect.height)))"
  }
}
