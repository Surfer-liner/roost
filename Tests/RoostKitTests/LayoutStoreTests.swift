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
    store.save(sampleLayout(fingerprint: "desk"))
    #expect(LayoutStore(fileURL: fileURL).layout(for: "desk") != nil)
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
