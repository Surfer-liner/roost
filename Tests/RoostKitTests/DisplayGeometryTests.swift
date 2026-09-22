import CoreGraphics
import Testing
@testable import RoostKit

@Suite struct DisplayGeometryTests {
  private let beforeReboot = [
    CGRect(x: 0, y: 0, width: 1512, height: 982),
    CGRect(x: -1488, y: 142, width: 1080, height: 1920),
    CGRect(x: 1512, y: 142, width: 1080, height: 1920),
    CGRect(x: -408, y: 982, width: 1920, height: 1080),
  ]

  private let afterReboot = [
    CGRect(x: 0, y: 0, width: 1512, height: 982),
    CGRect(x: -1080, y: 142, width: 1080, height: 1920),
    CGRect(x: 1920, y: 142, width: 1080, height: 1920),
    CGRect(x: 0, y: 982, width: 1920, height: 1080),
  ]

  @Test func theSameMonitorsKeepTheSameKeysWhenMacOSShiftsTheirOrigins() {
    let before = DisplayGeometry.displays(fromCocoaFrames: beforeReboot)
    let after = DisplayGeometry.displays(fromCocoaFrames: afterReboot)
    #expect(Set(before.map { $0.key }) == Set(after.map { $0.key }))
    #expect(DisplayFingerprint.fingerprint(of: before) == DisplayFingerprint.fingerprint(of: after))
    #expect(Set(after.map { $0.key }) == ["1512x982:main", "1080x1920:left", "1080x1920:right", "1920x1080:above"])
  }

  @Test func accessibilityRectsFlipTheCocoaOriginToTopLeft() {
    let displays = DisplayGeometry.displays(fromCocoaFrames: afterReboot)
    let above = displays.first { $0.key == "1920x1080:above" }
    #expect(above?.frame.rect == CGRect(x: 0, y: -1080, width: 1920, height: 1080))
    let main = displays.first { $0.key == "1512x982:main" }
    #expect(main?.frame.rect == CGRect(x: 0, y: 0, width: 1512, height: 982))
  }

  @Test func identicalMonitorsOnTheSameSideGetOrdinalsInLeftToRightOrder() {
    let frames = [
      CGRect(x: 0, y: 0, width: 1512, height: 982),
      CGRect(x: -2160, y: 0, width: 1080, height: 1920),
      CGRect(x: -1080, y: 0, width: 1080, height: 1920),
    ]
    let keys = DisplayGeometry.displays(fromCocoaFrames: frames).map { $0.key }
    #expect(keys.contains("1080x1920:left#1"))
    #expect(keys.contains("1080x1920:left#2"))
    #expect(keys.contains("1512x982:main"))
  }

  @Test func relocationKeepsTheWindowsOffsetInsideItsDisplay() {
    let before = DisplayGeometry.displays(fromCocoaFrames: beforeReboot)
    let after = DisplayGeometry.displays(fromCocoaFrames: afterReboot)
    let savedRight = before.first { $0.key == "1080x1920:right" }!
    let currentRight = after.first { $0.key == "1080x1920:right" }!
    let pyCharmBeforeReboot = CGRect(x: 1512, y: -1080, width: 1080, height: 1920)
    let moved = DisplayGeometry.relocate(pyCharmBeforeReboot, from: savedRight, to: currentRight)
    #expect(moved == CGRect(x: 1920, y: -1080, width: 1080, height: 1920))
    #expect(DisplayGeometry.display(containing: moved, among: after)?.key == "1080x1920:right")
  }

  @Test func legacyFingerprintStringsRebuildTheDisplaysTheyDescribe() {
    let legacy = "1080x1920@-1488,142 + 1080x1920@1512,142 + 1512x982@0,0 + 1920x1080@-408,982"
    let displays = DisplayGeometry.legacyDisplays(fromFingerprint: legacy)
    #expect(displays.count == 4)
    #expect(DisplayFingerprint.fingerprint(of: displays) == "1080x1920:left + 1080x1920:right + 1512x982:main + 1920x1080:above")
  }
}
