import CoreGraphics
import Foundation
import Testing
@testable import RoostKit

@Suite final class LayoutStoreTests {
  private let folder: URL
  private let fileURL: URL

  init() throws {
    folder = FileManager.default.temporaryDirectory.appendingPathComponent("roost-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    fileURL = folder.appendingPathComponent("layouts.json")
  }

  deinit {
    try? FileManager.default.removeItem(at: folder)
  }

  @Test func savedLayoutSurvivesRelaunch() {
    LayoutStore(fileURL: fileURL).save(sampleLayout(fingerprint: "desk"))
    #expect(LayoutStore(fileURL: fileURL).layout(for: "desk") == sampleLayout(fingerprint: "desk"))
  }

  @Test func eachDisplaySetupKeepsItsOwnLayout() {
    let store = LayoutStore(fileURL: fileURL)
    store.save(sampleLayout(fingerprint: "office triple-head"))
    store.save(sampleLayout(fingerprint: "naked laptop"))
    let reopened = LayoutStore(fileURL: fileURL)
    #expect(reopened.layout(for: "office triple-head") != nil)
    #expect(reopened.layout(for: "naked laptop") != nil)
    #expect(reopened.layout(for: "somewhere else") == nil)
  }

  @Test func layoutSavedBeforeMinimizeSupportStillLoads() throws {
    let legacy = """
    {"desk":{"displayFingerprint":"desk","savedAt":"2026-09-14T10:00:00Z","windows":[
      {"appBundleID":"com.apple.Safari","appName":"Safari","title":"News",
       "frame":{"x":10,"y":20,"width":800,"height":600}}]}}
    """
    try legacy.write(to: fileURL, atomically: true, encoding: .utf8)
    let loaded = LayoutStore(fileURL: fileURL).layout(for: "desk")
    #expect(loaded?.windows.count == 1)
    #expect(loaded?.windows.first?.isMinimized == false)
    #expect(loaded?.windows.first?.frame.rect == CGRect(x: 10, y: 20, width: 800, height: 600))
  }

  @Test func garbageFileYieldsEmptyStoreInsteadOfCrash() throws {
    try "this is not json".write(to: fileURL, atomically: true, encoding: .utf8)
    let store = LayoutStore(fileURL: fileURL)
    #expect(store.layout(for: "desk") == nil)
    #expect(store.save(sampleLayout(fingerprint: "desk")))
    #expect(LayoutStore(fileURL: fileURL).layout(for: "desk") != nil)
  }

  @Test func oneCorruptEntryDoesNotWipeTheHealthyOnes() throws {
    let mixed = """
    {
      "good": {"displayFingerprint":"good","savedAt":"2026-09-14T10:00:00Z","windows":[
        {"appBundleID":"com.apple.Safari","appName":"Safari","title":"News",
         "frame":{"x":10,"y":20,"width":800,"height":600},"isMinimized":false}]},
      "broken": {"displayFingerprint":"broken","savedAt":"not-a-date","windows":"garbage"}
    }
    """
    try mixed.write(to: fileURL, atomically: true, encoding: .utf8)
    let store = LayoutStore(fileURL: fileURL)
    #expect(store.layout(for: "good") != nil)
    #expect(store.layout(for: "broken") == nil)
  }

  @Test func savingDoesNotClobberEntriesAddedByAnotherWriter() {
    LayoutStore(fileURL: fileURL).save(sampleLayout(fingerprint: "office"))
    LayoutStore(fileURL: fileURL).save(sampleLayout(fingerprint: "home"))
    let reopened = LayoutStore(fileURL: fileURL)
    #expect(reopened.layout(for: "office") != nil)
    #expect(reopened.layout(for: "home") != nil)
  }

  @Test func legacyGeometryKeysAreUpgradedToDisplayKeysAndMergedNewestWins() throws {
    let legacy = """
    {
      "1080x1920@-1488,-30 + 1080x1920@1512,0 + 1512x982@0,0 + 1920x1080@-408,982": {
        "displayFingerprint": "1080x1920@-1488,-30 + 1080x1920@1512,0 + 1512x982@0,0 + 1920x1080@-408,982",
        "savedAt": "2026-09-14T12:47:44Z",
        "windows": [
          {"appBundleID":"a","appName":"A","title":"old","frame":{"x":556,"y":149,"width":400,"height":685}},
          {"appBundleID":"b","appName":"B","title":"old","frame":{"x":10,"y":10,"width":100,"height":100}},
          {"appBundleID":"c","appName":"C","title":"old","frame":{"x":20,"y":20,"width":100,"height":100}}
        ]
      },
      "1080x1920@-1488,142 + 1080x1920@1512,142 + 1512x982@0,0 + 1920x1080@-408,982": {
        "displayFingerprint": "1080x1920@-1488,142 + 1080x1920@1512,142 + 1512x982@0,0 + 1920x1080@-408,982",
        "savedAt": "2026-09-15T11:01:09Z",
        "windows": [
          {"appBundleID":"a","appName":"A","title":"new","frame":{"x":556,"y":149,"width":400,"height":685}},
          {"appBundleID":"b","appName":"B","title":"new","frame":{"x":-1400,"y":-800,"width":600,"height":400}}
        ]
      }
    }
    """
    try legacy.write(to: fileURL, atomically: true, encoding: .utf8)
    let layouts = LayoutStore(fileURL: fileURL).allLayouts()
    #expect(layouts.count == 1)
    let upgraded = try #require(layouts.first)
    #expect(upgraded.displayFingerprint == "1080x1920:left + 1080x1920:right + 1512x982:main + 1920x1080:above")
    #expect(upgraded.windows.count == 2)
    #expect(upgraded.windows.first { $0.appBundleID == "a" }?.displayKey == "1512x982:main")
    #expect(upgraded.windows.first { $0.appBundleID == "b" }?.displayKey == "1080x1920:left")
    #expect(upgraded.displays.count == 4)
  }

  @Test func bestLayoutIgnoresOriginDriftAndFallsBackToTheNewestForOtherDisplays() {
    let main = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let dockedBefore = DisplayGeometry.displays(fromCocoaFrames: [main, CGRect(x: -1488, y: 142, width: 1080, height: 1920)])
    let dockedAfterReboot = DisplayGeometry.displays(fromCocoaFrames: [main, CGRect(x: -1080, y: 142, width: 1080, height: 1920)])
    let laptopOnly = DisplayGeometry.displays(fromCocoaFrames: [main])
    let store = LayoutStore(fileURL: fileURL)
    #expect(store.bestLayout(for: dockedAfterReboot) == nil)
    store.save(Layout(
      displayFingerprint: DisplayFingerprint.fingerprint(of: dockedBefore),
      savedAt: Date(timeIntervalSince1970: 1_757_800_000),
      windows: [],
      displays: dockedBefore
    ))
    #expect(store.bestLayout(for: dockedAfterReboot)?.match == .sameDisplays)
    #expect(store.bestLayout(for: laptopOnly)?.match == .differentDisplays)
  }

  private func sampleLayout(fingerprint: String) -> Layout {
    Layout(
      displayFingerprint: fingerprint,
      savedAt: Date(timeIntervalSince1970: 1_757_800_000),
      windows: [
        WindowSnapshot(
          appBundleID: "com.apple.Safari",
          appName: "Safari",
          title: "News",
          frame: FrameSnapshot(CGRect(x: -1920, y: 40, width: 1920, height: 1040)),
          isMinimized: true
        )
      ]
    )
  }
}
