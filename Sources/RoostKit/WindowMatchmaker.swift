import CoreGraphics

protocol MatchableWindow {
  var appBundleID: String { get }
  var title: String { get }
  var frame: CGRect { get }
}

struct WindowMatch<Window: MatchableWindow> {
  let snapshot: WindowSnapshot
  let window: Window
}

enum WindowMatchmaker {
  static func pair<Window: MatchableWindow>(
    _ snapshots: [WindowSnapshot],
    with windows: [Window]
  ) -> [WindowMatch<Window>] {
    var matches: [WindowMatch<Window>] = []
    let windowsByApp = Dictionary(grouping: windows) { $0.appBundleID }
    for (bundleID, appSnapshots) in Dictionary(grouping: snapshots, by: { $0.appBundleID }) {
      matches += pairWithinOneApp(appSnapshots, windowsByApp[bundleID] ?? [])
    }
    return matches
  }

  private static func pairWithinOneApp<Window: MatchableWindow>(
    _ snapshots: [WindowSnapshot],
    _ windows: [Window]
  ) -> [WindowMatch<Window>] {
    var matches: [WindowMatch<Window>] = []
    var free = windows
    var driftedTitles: [WindowSnapshot] = []
    for snapshot in snapshots {
      if let exact = free.firstIndex(where: { $0.title == snapshot.title }) {
        matches.append(WindowMatch(snapshot: snapshot, window: free.remove(at: exact)))
      } else {
        driftedTitles.append(snapshot)
      }
    }
    for snapshot in driftedTitles {
      guard let nearest = free.indices.min(by: { distance(free[$0], snapshot) < distance(free[$1], snapshot) }) else { break }
      matches.append(WindowMatch(snapshot: snapshot, window: free.remove(at: nearest)))
    }
    return matches
  }

  private static func distance<Window: MatchableWindow>(_ window: Window, _ snapshot: WindowSnapshot) -> CGFloat {
    let home = snapshot.frame.rect
    return hypot(window.frame.midX - home.midX, window.frame.midY - home.midY)
  }
}
