import AppKit

final class LayoutRestorer {
  private let layout: Layout
  private let whenFinished: (Int, Int) -> Void
  private var pending: [WindowSnapshot]
  private var claimed: [AXUIElement] = []
  private var passesLeft = 20

  init(layout: Layout, whenFinished: @escaping (Int, Int) -> Void) {
    self.layout = layout
    self.whenFinished = whenFinished
    pending = layout.windows
  }

  func restore() {
    launchMissingApps()
    runPlacementPass()
  }

  private func launchMissingApps() {
    let running = Set(WindowCatalog.visibleApps().compactMap { $0.bundleIdentifier })
    let needed = Set(pending.map { $0.appBundleID })
    needed.subtracting(running).forEach(launch)
  }

  private func launch(_ bundleID: String) {
    guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = false
    NSWorkspace.shared.openApplication(at: appURL, configuration: configuration)
  }

  private func runPlacementPass() {
    placeEverythingThatMatches()
    if pending.isEmpty || passesLeft == 0 {
      whenFinished(layout.windows.count - pending.count, layout.windows.count)
      return
    }
    passesLeft -= 1
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.runPlacementPass() }
  }

  private func placeEverythingThatMatches() {
    let free = WindowCatalog.allWindows().filter { $0.isStandard && !isClaimed($0) }
    let freeByApp = Dictionary(grouping: free) { $0.app.bundleIdentifier ?? "" }
    for (bundleID, snapshots) in Dictionary(grouping: pending, by: { $0.appBundleID }) {
      settle(snapshots, into: freeByApp[bundleID] ?? [])
    }
  }

  private func settle(_ snapshots: [WindowSnapshot], into windows: [AppWindow]) {
    var free = windows
    var unmatchedByTitle: [WindowSnapshot] = []
    for snapshot in snapshots {
      if let match = free.firstIndex(where: { $0.title == snapshot.title }) {
        place(snapshot, onto: free.remove(at: match))
      } else {
        unmatchedByTitle.append(snapshot)
      }
    }
    for snapshot in unmatchedByTitle {
      if free.isEmpty { return }
      place(snapshot, onto: free.removeFirst())
    }
  }

  private func place(_ snapshot: WindowSnapshot, onto window: AppWindow) {
    if window.isMinimized {
      window.unminimize()
    }
    window.move(to: snapshot.frame.rect)
    claimed.append(window.element)
    if let index = pending.firstIndex(of: snapshot) {
      pending.remove(at: index)
    }
  }

  private func isClaimed(_ window: AppWindow) -> Bool {
    claimed.contains { CFEqual($0, window.element) }
  }
}
