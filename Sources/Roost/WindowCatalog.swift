import AppKit
import ApplicationServices

enum WindowCatalog {
  static func visibleApps() -> [NSRunningApplication] {
    NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular }
  }

  static func allWindows() -> [AppWindow] {
    visibleApps().flatMap { windows(of: $0) }
  }

  static func windows(of app: NSRunningApplication) -> [AppWindow] {
    let application = AXUIElementCreateApplication(app.processIdentifier)
    var list: CFTypeRef?
    AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &list)
    let elements = list as? [AXUIElement] ?? []
    return elements.map { AppWindow(app: app, element: $0) }
  }
}
