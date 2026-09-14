protocol MatchableWindow {
  var appBundleID: String { get }
  var title: String { get }
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
      if free.isEmpty { break }
      matches.append(WindowMatch(snapshot: snapshot, window: free.removeFirst()))
    }
    return matches
  }
}
