import CoreGraphics
import Testing
@testable import RoostKit

@Suite struct FrameSnapshotTests {
  @Test func frameSurvivesTheRoundTrip() {
    let original = CGRect(x: 15.5, y: 42, width: 1440, height: 900)
    #expect(FrameSnapshot(original).rect == original)
  }

  @Test func monitorLeftOfMainKeepsItsNegativeCoordinates() {
    let leftMonitor = CGRect(x: -1920, y: -180, width: 1920, height: 1080)
    #expect(FrameSnapshot(leftMonitor).rect == leftMonitor)
  }
}
