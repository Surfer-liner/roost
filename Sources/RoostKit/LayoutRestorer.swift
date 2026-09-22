import AppKit

public struct RestoreReport {
  public let placed: Int
  public let total: Int
  public let leftBehind: [String]

  public var everythingLanded: Bool {
    placed == total
  }
}

public final class LayoutRestorer {
  private enum Outcome {
    case pending
    case atHome
    case settledElsewhere
  }

  private final class Target {
    let snapshot: WindowSnapshot
    let home: CGRect
    let displayBounds: CGRect
    let matchingSnapshot: WindowSnapshot
    var window: AppWindow?
    var outcome = Outcome.pending
    var settledStreak = 0
    var restingStreak = 0
    var lastFrame: CGRect?
    var positionedWhileVisible = false
    var dockToggleTries = 0
    var fullScreenRelocateTries = 0

    init(snapshot: WindowSnapshot, home: CGRect, displayBounds: CGRect) {
      self.snapshot = snapshot
      self.home = home
      self.displayBounds = displayBounds
      matchingSnapshot = snapshot.placed(at: home)
    }

    var appBundleID: String {
      snapshot.appBundleID
    }

    var done: Bool {
      outcome != .pending
    }

    func forgetWindow() {
      window = nil
      outcome = .pending
      settledStreak = 0
      restingStreak = 0
      lastFrame = nil
      positionedWhileVisible = false
      dockToggleTries = 0
    }
  }

  private let layout: Layout
  private let whenFinished: (RestoreReport) -> Void
  private let targets: [Target]
  private var startedAt = Date()
  private var appsRunningBeforeRestore: Set<String> = []
  private var unreachableBundleIDs: Set<String> = []
  private var launchRequestedAt: [String: Date] = [:]
  private var firstSeenRunningAt: [String: Date] = [:]
  private var spawnAttemptsByApp: [String: Int] = [:]
  private var lastSpawnPassByApp: [String: Int] = [:]
  private var passesRun = 0
  private var lastDoneCount = -1
  private var lastWindowCount = -1
  private var stagnantPasses = 0

  private let placementInterval = 0.4
  private let overallDeadline: TimeInterval = 120
  private let windowlessLaunchGrace: TimeInterval = 90
  private let windowlessPreRunningGrace: TimeInterval = 15
  private let settleStreakNeeded = 2
  private let restingStreakBeforeAccepting = 5
  private let maxDockToggleTries = 3
  private let maxFullScreenRelocateTries = 4
  private let minPassesBetweenSpawns = 3
  private let stagnantPassesBeforeGivingUp = 20

  public init(layout: Layout, whenFinished: @escaping (RestoreReport) -> Void) {
    self.layout = layout
    self.whenFinished = whenFinished
    let currentDisplays = DisplayGeometry.currentDisplays()
    targets = layout.windows.map { snapshot in
      let placement = Self.placement(for: snapshot, savedOn: layout.displays, now: currentDisplays)
      return Target(snapshot: snapshot, home: placement.home, displayBounds: placement.displayBounds)
    }
  }

  private static func placement(
    for snapshot: WindowSnapshot,
    savedOn saved: [DisplaySnapshot],
    now current: [DisplaySnapshot]
  ) -> (home: CGRect, displayBounds: CGRect) {
    let frame = snapshot.frame.rect
    if let key = snapshot.displayKey,
       let from = saved.first(where: { $0.key == key }),
       let to = current.first(where: { $0.key == key }) {
      return (DisplayGeometry.relocate(frame, from: from, to: to), to.frame.rect)
    }
    if let onScreen = DisplayGeometry.display(containing: frame, among: current) {
      return (frame, onScreen.frame.rect)
    }
    guard let fallback = current.first(where: { $0.key.hasSuffix(":main") }) ?? current.first else {
      return (frame, frame)
    }
    let bounds = fallback.frame.rect
    let parked = CGRect(
      x: bounds.minX + 40,
      y: bounds.minY + 60,
      width: min(frame.width, bounds.width - 80),
      height: min(frame.height, bounds.height - 100)
    )
    return (parked, bounds)
  }

  public func restore() {
    startedAt = Date()
    appsRunningBeforeRestore = Set(WindowCatalog.visibleApps().compactMap { $0.bundleIdentifier })
    launchAppsThatAreNotRunning()
    runPlacementPass()
  }

  private func launchAppsThatAreNotRunning() {
    let needed = Set(targets.map { $0.appBundleID })
    for bundleID in needed.subtracting(appsRunningBeforeRestore) {
      guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
        unreachableBundleIDs.insert(bundleID)
        continue
      }
      launchRequestedAt[bundleID] = Date()
      openQuietly(appURL)
    }
  }

  private func runPlacementPass() {
    passesRun += 1
    let live = liveWindows()
    noteAppsThatCameUp()
    forgetWindowsThatVanished(among: live)
    matchFreeTargetsToFreeWindows(among: live)
    placeMatchedTargets(given: live)
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

  private func noteAppsThatCameUp() {
    for bundleID in Set(targets.map { $0.appBundleID }) where firstSeenRunningAt[bundleID] == nil {
      if runningApp(bundleID) != nil {
        firstSeenRunningAt[bundleID] = Date()
      }
    }
  }

  private func forgetWindowsThatVanished(among live: [AppWindow]) {
    for target in targets {
      guard let window = target.window else { continue }
      if target.done || target.snapshot.isFullScreen {
        continue
      }
      if live.contains(where: { CFEqual($0.element, window.element) }) {
        continue
      }
      if let sameWindowSeenAgain = liveTwin(of: window, among: live) {
        target.window = sameWindowSeenAgain
      } else {
        target.forgetWindow()
      }
    }
  }

  private func liveTwin(of window: AppWindow, among live: [AppWindow]) -> AppWindow? {
    let claimed = targets.compactMap { $0.window?.element }
    return live.first { candidate in
      candidate.appBundleID == window.appBundleID &&
        candidate.title == window.title &&
        !claimed.contains { CFEqual($0, candidate.element) }
    }
  }

  private func matchFreeTargetsToFreeWindows(among live: [AppWindow]) {
    let claimed = targets.compactMap { $0.window?.element }
    let freeWindows = live.filter { candidate in
      !claimed.contains { CFEqual($0, candidate.element) }
    }
    let freeTargets = targets.filter { $0.window == nil }
    for match in WindowMatchmaker.pair(freeTargets.map { $0.matchingSnapshot }, with: freeWindows) {
      guard let target = freeTargets.first(where: { $0.window == nil && $0.matchingSnapshot == match.snapshot }) else { continue }
      target.window = match.window
    }
  }

  private func placeMatchedTargets(given live: [AppWindow]) {
    for target in targets where !target.done {
      guard let window = target.window else { continue }
      if target.snapshot.isFullScreen {
        keepFullScreenOnItsDisplay(target, window, given: live)
      } else if target.snapshot.isMinimized {
        keepMinimizedWindowParked(target, window)
      } else {
        keepVisibleWindowHome(target, window)
      }
    }
  }

  private func everyWindowIsAccountedForAsNormal(given live: [AppWindow]) -> Bool {
    targets.allSatisfy { $0.window != nil || isHopeless($0, given: live) } &&
      targets.filter { !$0.snapshot.isFullScreen && $0.window != nil }.allSatisfy { $0.done }
  }

  private func isHopeless(_ target: Target, given live: [AppWindow]) -> Bool {
    guard target.window == nil else { return false }
    if unreachableBundleIDs.contains(target.appBundleID) {
      return true
    }
    if appIsStillWakingUp(target.appBundleID, given: live) {
      return false
    }
    let appTargets = targets.filter { $0.appBundleID == target.appBundleID }
    return !spawnPlan(for: target.appBundleID, of: appTargets).hasAttemptsLeft
  }

  private func keepFullScreenOnItsDisplay(_ target: Target, _ window: AppWindow, given live: [AppWindow]) {
    let displayBounds = target.displayBounds
    let isOnItsDisplay = displayBounds.contains(CGPoint(x: window.frame.midX, y: window.frame.midY))
    if window.isFullScreen && isOnItsDisplay && !appNeedsMoreWindows(target.appBundleID, given: live) {
      target.outcome = .atHome
      return
    }
    guard everyWindowIsAccountedForAsNormal(given: live) else {
      settleOntoItsDisplayAsNormalWindow(window, displayBounds: displayBounds)
      return
    }
    let stopRelocating = target.fullScreenRelocateTries >= maxFullScreenRelocateTries
    if window.isFullScreen {
      if stopRelocating {
        target.outcome = .settledElsewhere
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

  private func settleOntoItsDisplayAsNormalWindow(_ window: AppWindow, displayBounds: CGRect) {
    if window.isFullScreen {
      window.setFullScreen(false)
    } else if !displayBounds.contains(CGPoint(x: window.frame.midX, y: window.frame.midY)) {
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
    let current = window.frame
    if Geometry.isSettled(current, at: target.home) {
      target.settledStreak += 1
      target.restingStreak = 0
      if target.settledStreak >= settleStreakNeeded {
        target.outcome = .atHome
      }
      target.lastFrame = current
      return
    }
    target.settledStreak = 0
    if let last = target.lastFrame, Geometry.hasNotMoved(current, since: last) {
      target.restingStreak += 1
      if target.restingStreak >= restingStreakBeforeAccepting {
        target.outcome = .settledElsewhere
      }
      return
    }
    target.restingStreak = 0
    window.move(to: target.home)
    target.lastFrame = window.frame
  }

  private func appNeedsMoreWindows(_ bundleID: String, given live: [AppWindow]) -> Bool {
    targets.filter { $0.appBundleID == bundleID }.count > live.filter { $0.appBundleID == bundleID }.count
  }

  private func keepMinimizedWindowParked(_ target: Target, _ window: AppWindow) {
    if window.isMinimized && !target.positionedWhileVisible {
      target.dockToggleTries += 1
      if target.dockToggleTries > maxDockToggleTries {
        target.outcome = .atHome
        return
      }
      window.unminimize()
      return
    }
    if !target.positionedWhileVisible {
      window.move(to: target.home)
      target.positionedWhileVisible = true
      return
    }
    if window.isMinimized {
      target.outcome = .atHome
      return
    }
    target.dockToggleTries += 1
    if target.dockToggleTries > maxDockToggleTries {
      target.outcome = .atHome
      return
    }
    window.minimize()
  }

  private func spawnMissingWindows(given live: [AppWindow]) {
    for (bundleID, appTargets) in Dictionary(grouping: targets, by: { $0.appBundleID }) {
      guard !unreachableBundleIDs.contains(bundleID) else { continue }
      guard !appIsStillWakingUp(bundleID, given: live) else { continue }
      guard !live.contains(where: { $0.appBundleID == bundleID && $0.isFullScreen }) else { continue }
      guard spawnPlan(for: bundleID, of: appTargets).shouldSpawnOne else { continue }
      guard let app = runningApp(bundleID) else { continue }
      let openWindows = live.filter { $0.appBundleID == bundleID }.count
      if openWindows == 0 {
        reopenMainWindow(of: app)
      } else {
        WindowSummoner.requestOneMoreWindow(from: app)
      }
      spawnAttemptsByApp[bundleID, default: 0] += 1
      lastSpawnPassByApp[bundleID] = passesRun
    }
  }

  private func spawnPlan(for bundleID: String, of appTargets: [Target]) -> WindowSpawnPlan {
    let alreadyHandled = appTargets.filter { $0.window != nil || $0.done }.count
    return WindowSpawnPlan(
      neededWindows: appTargets.count,
      currentWindows: alreadyHandled,
      attemptsSoFar: spawnAttemptsByApp[bundleID] ?? 0,
      passesSinceLastAttempt: passesRun - (lastSpawnPassByApp[bundleID] ?? -minPassesBetweenSpawns),
      minPassesBetweenAttempts: minPassesBetweenSpawns,
      maxAttempts: appTargets.count + 2
    )
  }

  private func appIsStillWakingUp(_ bundleID: String, given live: [AppWindow]) -> Bool {
    if live.contains(where: { $0.appBundleID == bundleID }) {
      return false
    }
    if appsRunningBeforeRestore.contains(bundleID) {
      return Date().timeIntervalSince(startedAt) < windowlessPreRunningGrace
    }
    guard let since = firstSeenRunningAt[bundleID] ?? launchRequestedAt[bundleID] else { return false }
    return Date().timeIntervalSince(since) < windowlessLaunchGrace
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
    if Date().timeIntervalSince(startedAt) >= overallDeadline {
      return true
    }
    if targets.contains(where: { $0.window == nil && appIsStillWakingUp($0.appBundleID, given: live) }) {
      return false
    }
    return stagnantPasses >= stagnantPassesBeforeGivingUp && noAppCanProduceMoreWindows(given: live)
  }

  private func noAppCanProduceMoreWindows(given live: [AppWindow]) -> Bool {
    for (bundleID, appTargets) in Dictionary(grouping: targets, by: { $0.appBundleID }) {
      if unreachableBundleIDs.contains(bundleID) {
        continue
      }
      if appIsStillWakingUp(bundleID, given: live) {
        return false
      }
      let plan = spawnPlan(for: bundleID, of: appTargets)
      if plan.isMissingWindows, plan.hasAttemptsLeft {
        return false
      }
    }
    return true
  }

  private func finish() {
    let leftBehind = targets
      .filter { $0.outcome != .atHome }
      .map { "\($0.snapshot.appName): \($0.snapshot.title) (\(describe($0)))" }
    whenFinished(RestoreReport(
      placed: targets.count - leftBehind.count,
      total: targets.count,
      leftBehind: leftBehind
    ))
  }

  private func describe(_ target: Target) -> String {
    if unreachableBundleIDs.contains(target.appBundleID) {
      return "app not installed"
    }
    guard let window = target.window else {
      return "no window appeared"
    }
    let ended = target.outcome == .settledElsewhere ? "settled off its saved spot" : "still moving when time ran out"
    return "\(ended): at \(compact(window.frame)), wanted \(compact(target.home)), minimized=\(window.isMinimized), fullscreen=\(window.isFullScreen)"
  }

  private func compact(_ rect: CGRect) -> String {
    "\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))x\(Int(rect.height))"
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
