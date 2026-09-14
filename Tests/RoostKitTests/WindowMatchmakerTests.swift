import CoreGraphics
import Testing
@testable import RoostKit

private struct FakeWindow: MatchableWindow, Equatable {
  let appBundleID: String
  let title: String
  let badge: Int
}

@Suite struct WindowMatchmakerTests {
  @Test func exactTitleMatchWinsOverOrder() {
    let snapshots = [snapshot("editor", "Docs"), snapshot("editor", "Mail")]
    let windows = [window("editor", "Mail", 1), window("editor", "Docs", 2)]
    let matches = WindowMatchmaker.pair(snapshots, with: windows)
    #expect(matches.count == 2)
    #expect(badge(matches, forTitle: "Docs") == 2)
    #expect(badge(matches, forTitle: "Mail") == 1)
  }

  @Test func driftedTitlesFallBackToOrder() {
    let snapshots = [snapshot("browser", "Old news"), snapshot("browser", "Old mail")]
    let windows = [window("browser", "Fresh tab", 1), window("browser", "Another tab", 2)]
    let matches = WindowMatchmaker.pair(snapshots, with: windows)
    #expect(badge(matches, forTitle: "Old news") == 1)
    #expect(badge(matches, forTitle: "Old mail") == 2)
  }

  @Test func exactMatchesAreTakenBeforeOrderFallbackGrabsThem() {
    let snapshots = [snapshot("editor", "Drifted"), snapshot("editor", "Stable")]
    let windows = [window("editor", "Stable", 1), window("editor", "Whatever", 2)]
    let matches = WindowMatchmaker.pair(snapshots, with: windows)
    #expect(badge(matches, forTitle: "Stable") == 1)
    #expect(badge(matches, forTitle: "Drifted") == 2)
  }

  @Test func windowsNeverCrossBetweenApps() {
    let snapshots = [snapshot("editor", "Docs")]
    let windows = [window("browser", "Docs", 1)]
    #expect(WindowMatchmaker.pair(snapshots, with: windows).isEmpty)
  }

  @Test func leftoverSnapshotsStayUnmatchedWhenWindowsRunOut() {
    let snapshots = [snapshot("editor", "One"), snapshot("editor", "Two"), snapshot("editor", "Three")]
    let windows = [window("editor", "Two", 1)]
    let matches = WindowMatchmaker.pair(snapshots, with: windows)
    #expect(matches.count == 1)
    #expect(badge(matches, forTitle: "Two") == 1)
  }

  @Test func extraWindowsAreLeftAlone() {
    let snapshots = [snapshot("editor", "Only one saved")]
    let windows = [window("editor", "Only one saved", 1), window("editor", "Newcomer", 2)]
    let matches = WindowMatchmaker.pair(snapshots, with: windows)
    #expect(matches.count == 1)
    #expect(badge(matches, forTitle: "Only one saved") == 1)
  }

  @Test func twinTitlesEachGetTheirOwnWindow() {
    let snapshots = [snapshot("editor", "Untitled"), snapshot("editor", "Untitled")]
    let windows = [window("editor", "Untitled", 1), window("editor", "Untitled", 2)]
    let matches = WindowMatchmaker.pair(snapshots, with: windows)
    #expect(matches.count == 2)
    #expect(Set(matches.map { $0.window.badge }) == [1, 2])
  }

  private func snapshot(_ bundleID: String, _ title: String) -> WindowSnapshot {
    WindowSnapshot(appBundleID: bundleID, appName: bundleID, title: title, frame: FrameSnapshot(.zero), isMinimized: false)
  }

  private func window(_ bundleID: String, _ title: String, _ badge: Int) -> FakeWindow {
    FakeWindow(appBundleID: bundleID, title: title, badge: badge)
  }

  private func badge(_ matches: [WindowMatch<FakeWindow>], forTitle title: String) -> Int? {
    matches.first { $0.snapshot.title == title }?.window.badge
  }
}
