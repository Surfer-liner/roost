import AppKit

public final class LayoutRestorer {
  private final class Target {
    let snapshot: WindowSnapshot
    var window: AppWindow?
    var settledStreak = 0
    var positionedWhileVisible = false
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
    forgetWindowsThatVanished()
    matchFreeTargetsToFreeWindows()
    placeMatchedTargets()
    spawnMissingWindows()
    trackProgress()
    if shouldStop() {
      finish()
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + placementInterval) { self.runPlacementPass() }
  }

  private func liveWindows() -> [AppWindow] {
    WindowCatalog.allWindows().filter { $0.isRestorable }
  }

  private func forgetWindowsThatVanished() {
    let live = liveWindows()
    for target in targets {
      guard let window = target.window else { continue }
      if !live.contains(where: { CFEqual($0.element, window.element) }) {
        target.window = nil
        target.done = false
        target.settledStreak = 0
        target.positionedWhileVisible = false
      }
    }
  }

  private func matchFreeTargetsToFreeWindows() {
    let claimed = targets.compactMap { $0.window?.element }
    let freeWindows = liveWindows().filter { candidate in
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
      if target.snapshot.isMinimized {
        keepMinimizedWindowParked(target, window)
      } else {
        keepVisibleWindowHome(target, window)
      }
    }
  }

  private func keepVisibleWindowHome(_ target: Target, _ window: AppWindow) {
    if window.app.isHidden {
      window.app.unhide()
      target.settledStreak = 0
      return
    }
    if window.isMinimized {
      window.unminimize()
      target.settledStreak = 0
      return
    }
    let home = target.snapshot.frame.rect
    if Geometry.isSettled(window.frame, at: home) {
      target.settledStreak += 1
    } else {
      window.move(to: home)
      target.settledStreak = 0
    }
    if target.settledStreak >= settleStreakNeeded {
      target.done = true
    }
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

  private func spawnMissingWindows() {
    let neededByApp = countByApp(targets.map { $0.appBundleID })
    let haveByApp = countByApp(liveWindows().map { $0.appBundleID })
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

  private func trackProgress() {
    let doneNow = targets.filter { $0.done }.count
    let windowsNow = liveWindows().count
    if doneNow == lastDoneCount && windowsNow == lastWindowCount {
      stagnantPasses += 1
    } else {
      stagnantPasses = 0
    }
    lastDoneCount = doneNow
    lastWindowCount = windowsNow
  }

  private func shouldStop() -> Bool {
    if targets.allSatisfy({ $0.done }) {
      return true
    }
    if passesRun >= maxPasses {
      return true
    }
    return stagnantPasses >= stagnantPassesBeforeGivingUp && noAppCanProduceMoreWindows()
  }

  private func noAppCanProduceMoreWindows() -> Bool {
    let neededByApp = countByApp(targets.map { $0.appBundleID })
    let haveByApp = countByApp(liveWindows().map { $0.appBundleID })
    for (bundleID, needed) in neededByApp {
      let have = haveByApp[bundleID] ?? 0
      if appIsStillWakingUp(bundleID) {
        return false
      }
      if spawnPlan(for: bundleID, needed: needed, have: have).isMissingWindows,
         spawnPlan(for: bundleID, needed: needed, have: have).hasAttemptsLeft {
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
