import AppKit

public final class LayoutRestorer {
  private final class Target {
    let snapshot: WindowSnapshot
    var window: AppWindow?
    var settledStreak = 0
    var restingStreak = 0
    var lastFrame: CGRect?
    var positionedWhileVisible = false
    var fullScreenRelocateTries = 0
    var done = false

    init(_ snapshot: WindowSnapshot) {
      self.snapshot = snapshot
    }

    var appBundleID: String {
      snapshot.appBundleID
    }
  }

  private let layout: Layout
  private let whenFinished: (Int, Int) -> Void
  private let targets: [Target]
  private var appsRunningBeforeRestore: Set<String> = []
  private var spawnAttemptsByApp: [String: Int] = [:]
  private var lastSpawnPassByApp: [String: Int] = [:]
  private var passesRun = 0
  private var lastDoneCount = -1
  private var lastWindowCount = -1
  private var stagnantPasses = 0

  private let placementInterval = 0.4
  private let maxPasses = 60
  private let settleStreakNeeded = 2
  private let restingStreakBeforeAccepting = 5
  private let maxFullScreenRelocateTries = 4
  private let minPassesBetweenSpawns = 3
  private let freshLaunchGracePasses = 12
  private let stagnantPassesBeforeGivingUp = 20

  public init(layout: Layout, whenFinished: @escaping (Int, Int) -> Void) {
    self.layout = layout
    self.whenFinished = whenFinished
    targets = layout.windows.map(Target.init)
  }

  public func restore() {
    appsRunningBeforeRestore = Set(WindowCatalog.visibleApps().compactMap { $0.bundleIdentifier })
    launchAppsThatAreNotRunning()
    runPlacementPass()
  }

  private func launchAppsThatAreNotRunning() {
    let needed = Set(targets.map { $0.appBundleID })
    for bundleID in needed.subtracting(appsRunningBeforeRestore) {
      guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { continue }
      openQuietly(appURL)
    }
  }

  private func runPlacementPass() {
    passesRun += 1
    let live = liveWindows()
    forgetWindowsThatVanished(among: live)
    matchFreeTargetsToFreeWindows(among: live)
    placeMatchedTargets()
    spawnMissingWindows(given: live)
    trackProgress(given: live)
    if shouldStop(given: live) {
      finish()
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + placementInterval) { self.runPlacementPass() }
  }

  private func liveWindows() -> [AppWindow] {
    WindowCatalog.allWindows().filter { $0.isRestorable }
  }

  private func forgetWindowsThatVanished(among live: [AppWindow]) {
    for target in targets {
      guard let window = target.window else { continue }
      if !live.contains(where: { CFEqual($0.element, window.element) }) {
        target.window = nil
        target.done = false
        target.settledStreak = 0
        target.restingStreak = 0
        target.lastFrame = nil
        target.positionedWhileVisible = false
      }
    }
  }

  private func matchFreeTargetsToFreeWindows(among live: [AppWindow]) {
    let claimed = targets.compactMap { $0.window?.element }
    let freeWindows = live.filter { candidate in
      !claimed.contains { CFEqual($0, candidate.element) }
    }
    let freeTargets = targets.filter { $0.window == nil }
    for match in WindowMatchmaker.pair(freeTargets.map { $0.snapshot }, with: freeWindows) {
      guard let target = freeTargets.first(where: { $0.window == nil && $0.snapshot == match.snapshot }) else { continue }
      target.window = match.window
    }
  }

  private func placeMatchedTargets() {
    for target in targets where !target.done {
      guard let window = target.window else { continue }
      if target.snapshot.isFullScreen {
        keepFullScreenOnItsDisplay(target, window)
      } else if target.snapshot.isMinimized {
        keepMinimizedWindowParked(target, window)
      } else {
        keepVisibleWindowHome(target, window)
      }
    }
  }

  private func keepFullScreenOnItsDisplay(_ target: Target, _ window: AppWindow) {
    let displayBounds = target.snapshot.frame.rect
    let isOnItsDisplay = displayBounds.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
    let stopRelocating = target.fullScreenRelocateTries >= maxFullScreenRelocateTries
    if window.isFullScreen {
      if isOnItsDisplay || stopRelocating {
        target.done = true
      } else {
        target.fullScreenRelocateTries += 1
        window.setFullScreen(false)
      }
      return
    }
    if isOnItsDisplay || stopRelocating {
      window.setFullScreen(true)
    } else {
      target.fullScreenRelocateTries += 1
      window.move(to: displayBounds.insetBy(dx: displayBounds.width * 0.25, dy: displayBounds.height * 0.25))
    }
  }

  private func keepVisibleWindowHome(_ target: Target, _ window: AppWindow) {
    if window.isFullScreen {
      window.setFullScreen(false)
      target.settledStreak = 0
      target.restingStreak = 0
      return
    }
    if window.app.isHidden {
      window.app.unhide()
      target.settledStreak = 0
      target.restingStreak = 0
      return
    }
    if window.isMinimized {
      window.unminimize()
      target.settledStreak = 0
      target.restingStreak = 0
      return
    }
    let home = target.snapshot.frame.rect
    let current = window.frame
    if Geometry.isSettled(current, at: home) {
      target.settledStreak += 1
      target.restingStreak = 0
      if target.settledStreak >= settleStreakNeeded {
        target.done = true
      }
      target.lastFrame = current
      return
    }
    target.settledStreak = 0
    if let last = target.lastFrame, Geometry.isSettled(current, at: last, positionTolerance: 2, sizeTolerance: 2) {
      target.restingStreak += 1
      if target.restingStreak >= restingStreakBeforeAccepting {
        target.done = true
      }
      return
    }
    target.restingStreak = 0
    window.move(to: home)
    target.lastFrame = window.frame
  }

  private func keepMinimizedWindowParked(_ target: Target, _ window: AppWindow) {
    if window.isMinimized && !target.positionedWhileVisible {
      window.unminimize()
      return
    }
    if !target.positionedWhileVisible {
      window.move(to: target.snapshot.frame.rect)
      target.positionedWhileVisible = true
      return
    }
    if window.isMinimized {
      target.done = true
    } else {
      window.minimize()
    }
  }

  private func spawnMissingWindows(given live: [AppWindow]) {
    let neededByApp = countByApp(targets.map { $0.appBundleID })
    let haveByApp = countByApp(live.map { $0.appBundleID })
    for (bundleID, needed) in neededByApp {
      let have = haveByApp[bundleID] ?? 0
      guard shouldSpawnWindow(for: bundleID, needed: needed, have: have) else { continue }
      guard let app = runningApp(bundleID) else { continue }
      if have == 0 {
        reopenMainWindow(of: app)
      } else {
        WindowSummoner.requestOneMoreWindow(from: app)
      }
      spawnAttemptsByApp[bundleID, default: 0] += 1
      lastSpawnPassByApp[bundleID] = passesRun
    }
  }

  private func shouldSpawnWindow(for bundleID: String, needed: Int, have: Int) -> Bool {
    if appIsStillWakingUp(bundleID) {
      return false
    }
    return spawnPlan(for: bundleID, needed: needed, have: have).shouldSpawnOne
  }

  private func spawnPlan(for bundleID: String, needed: Int, have: Int) -> WindowSpawnPlan {
    WindowSpawnPlan(
      neededWindows: needed,
      currentWindows: have,
      attemptsSoFar: spawnAttemptsByApp[bundleID] ?? 0,
      passesSinceLastAttempt: passesRun - (lastSpawnPassByApp[bundleID] ?? -minPassesBetweenSpawns),
      minPassesBetweenAttempts: minPassesBetweenSpawns,
      maxAttempts: needed + 2
    )
  }

  private func appIsStillWakingUp(_ bundleID: String) -> Bool {
    !appsRunningBeforeRestore.contains(bundleID) && passesRun < freshLaunchGracePasses
  }

  private func trackProgress(given live: [AppWindow]) {
    let doneNow = targets.filter { $0.done }.count
    let windowsNow = live.count
    if doneNow == lastDoneCount && windowsNow == lastWindowCount {
      stagnantPasses += 1
    } else {
      stagnantPasses = 0
    }
    lastDoneCount = doneNow
    lastWindowCount = windowsNow
  }

  private func shouldStop(given live: [AppWindow]) -> Bool {
    if targets.allSatisfy({ $0.done }) {
      return true
    }
    if passesRun >= maxPasses {
      return true
    }
    return stagnantPasses >= stagnantPassesBeforeGivingUp && noAppCanProduceMoreWindows(given: live)
  }

  private func noAppCanProduceMoreWindows(given live: [AppWindow]) -> Bool {
    let neededByApp = countByApp(targets.map { $0.appBundleID })
    let haveByApp = countByApp(live.map { $0.appBundleID })
    for (bundleID, needed) in neededByApp {
      let have = haveByApp[bundleID] ?? 0
      if appIsStillWakingUp(bundleID) {
        return false
      }
      let plan = spawnPlan(for: bundleID, needed: needed, have: have)
      if plan.isMissingWindows, plan.hasAttemptsLeft {
        return false
      }
    }
    return true
  }

  private func finish() {
    let placed = targets.filter { $0.done }.count
    whenFinished(placed, targets.count)
  }

  private func countByApp(_ bundleIDs: [String]) -> [String: Int] {
    Dictionary(grouping: bundleIDs, by: { $0 }).mapValues { $0.count }
  }

  private func reopenMainWindow(of app: NSRunningApplication) {
    guard let appURL = app.bundleURL else { return }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
  }

  private func openQuietly(_ appURL: URL) {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
  }

  private func runningApp(_ bundleID: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
  }
}
