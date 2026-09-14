import CoreGraphics
import Testing
@testable import RoostKit

@Suite struct GeometryTests {
  @Test func exactMatchIsSettled() {
    let frame = CGRect(x: 100, y: 200, width: 800, height: 600)
    #expect(Geometry.isSettled(frame, at: frame))
  }

  @Test func aFewPixelsOfDriftStillCountsAsSettled() {
    let target = CGRect(x: 100, y: 200, width: 800, height: 600)
    let almost = CGRect(x: 104, y: 197, width: 810, height: 600)
    #expect(Geometry.isSettled(almost, at: target))
  }

  @Test func aWindowStrandedOnTheWrongMonitorIsNotSettled() {
    let home = CGRect(x: -1920, y: 40, width: 1200, height: 800)
    let strandedOnMain = CGRect(x: 300, y: 40, width: 1200, height: 800)
    #expect(!Geometry.isSettled(strandedOnMain, at: home))
  }

  @Test func aResizedWindowIsNotSettled() {
    let home = CGRect(x: 100, y: 100, width: 1200, height: 800)
    let shrunk = CGRect(x: 100, y: 100, width: 600, height: 400)
    #expect(!Geometry.isSettled(shrunk, at: home))
  }
}
