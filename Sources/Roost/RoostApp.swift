import AppKit

final class RoostApp: NSObject, NSApplicationDelegate {
  private var statusMenu: StatusMenu?

  func applicationDidFinishLaunching(_ notification: Notification) {
    statusMenu = StatusMenu()
    AccessibilityPermission.askIfNeeded()
  }
}
