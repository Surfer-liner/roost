import AppKit

public final class LayoutRestorer {
  private let layout: Layout
  private let whenFinished: (Int, Int) -> Void
  private var pending: [WindowSnapshot]
  private var claimed: [AXUIElement] = []
  private var alreadyRunningBundleIDs: Set<String> = []
  private var reopenedBundleIDs: Set<String> = []
  private var passesRun = 0
  private let maxPasses = 30
  private let freshLaunchGracePasses = 8

  public init(layout: Layout, whenFinished: @escaping (Int, Int) -> Void) {
    self.layout = layout
    self.whenFinished = whenFinished
    pending = layout.windows
  }

  public func restore() {
    alreadyRunningBundleIDs = Set(WindowCatalog.visibleApps().compactMap { $0.bundleIdentifier })
    launchAppsThatAreNotRunning()
    runPlacementPass()
  }

  private func launchAppsThatAreNotRunning() {
    let needed = Set(pending.map { $0.appBundleID })
    for bundleID in needed.subtracting(alreadyRunningBundleIDs) {
      guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { continue }
      openQuietly(appURL)
    }
  }

  private func runPlacementPass() {
    passesRun += 1
    placeEverythingThatMatches()
    summonWindowsForWindowlessApps()
    if pending.isEmpty || passesRun == maxPasses {
      whenFinished(layout.windows.count - pending.count, layout.windows.count)
      return
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.runPlacementPass() }
  }

  private func placeEverythingThatMatches() {
    let free = WindowCatalog.allWindows().filter { $0.isRestorable && !isClaimed($0) }
    for match in WindowMatchmaker.pair(pending, with: free) {
      place(match.snapshot, onto: match.window)
    }
  }

  private func summonWindowsForWindowlessApps() {
    for bundleID in Set(pending.map { $0.appBundleID }) where deservesReopen(bundleID) {
      guard let app = runningApp(bundleID), restorableWindowCount(of: app) == 0 else { continue }
      guard let appURL = app.bundleURL else { continue }
      reopenedBundleIDs.insert(bundleID)
      openQuietly(appURL)
    }
  }

  private func deservesReopen(_ bundleID: String) -> Bool {
    guard !reopenedBundleIDs.contains(bundleID) else { return false }
    let wasAlreadyRunning = alreadyRunningBundleIDs.contains(bundleID)
    let gaveFreshLaunchTimeToShowWindows = passesRun >= freshLaunchGracePasses
    return wasAlreadyRunning || gaveFreshLaunchTimeToShowWindows
  }

  private func place(_ snapshot: WindowSnapshot, onto window: AppWindow) {
    if snapshot.isMinimized {
      tuckAwayMinimized(window, at: snapshot.frame.rect)
    } else {
      bringBack(window, to: snapshot.frame.rect)
    }
    claimed.append(window.element)
    if let index = pending.firstIndex(of: snapshot) {
      pending.remove(at: index)
    }
  }

  private func bringBack(_ window: AppWindow, to home: CGRect) {
    if window.app.isHidden {
      window.app.unhide()
    }
    if window.isMinimized {
      window.unminimize()
    }
    window.move(to: home)
  }

  private func tuckAwayMinimized(_ window: AppWindow, at home: CGRect) {
    if window.isMinimized {
      window.unminimize()
    }
    window.move(to: home)
    window.minimize()
  }

  private func openQuietly(_ appURL: URL) {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
  }

  private func runningApp(_ bundleID: String) -> NSRunningApplication? {
    NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
  }

  private func restorableWindowCount(of app: NSRunningApplication) -> Int {
    WindowCatalog.windows(of: app).filter { $0.isRestorable }.count
  }

  private func isClaimed(_ window: AppWindow) -> Bool {
    claimed.contains { CFEqual($0, window.element) }
  }
}
