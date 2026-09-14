import AppKit
import ApplicationServices

public enum WindowSummoner {
  @discardableResult
  public static func requestOneMoreWindow(from app: NSRunningApplication) -> Bool {
    let application = AXUIElementCreateApplication(app.processIdentifier)
    return pressNewWindowMenuItem(in: application)
  }

  private static func pressNewWindowMenuItem(in application: AXUIElement) -> Bool {
    guard let menuBar = attribute(application, kAXMenuBarAttribute) else { return false }
    var lastOpenedMenuItem: AXUIElement?
    for menuBarItem in children(of: menuBar) {
      guard let menu = submenu(of: menuBarItem) else { continue }
      openIfEmpty(menu, byPressing: menuBarItem)
      lastOpenedMenuItem = menuBarItem
      if let target = searchForNewWindowItem(in: menu, depth: 0) {
        Thread.sleep(forTimeInterval: 0.05)
        AXUIElementPerformAction(target, kAXPressAction as CFString)
        return true
      }
    }
    if let lastOpenedMenuItem {
      AXUIElementPerformAction(lastOpenedMenuItem, kAXCancelAction as CFString)
    }
    return false
  }

  private static func searchForNewWindowItem(in menu: AXUIElement, depth: Int) -> AXUIElement? {
    guard depth < 4 else { return nil }
    for item in children(of: menu) {
      if isBoundToCommandN(item), isEnabled(item) {
        return item
      }
      if let nested = submenu(of: item) {
        openIfEmpty(nested, byPressing: item)
        if let found = searchForNewWindowItem(in: nested, depth: depth + 1) {
          return found
        }
      }
    }
    return nil
  }

  private static func isBoundToCommandN(_ item: AXUIElement) -> Bool {
    string(item, "AXMenuItemCmdChar")?.lowercased() == "n" && number(item, "AXMenuItemCmdModifiers") == 0
  }

  private static func isEnabled(_ item: AXUIElement) -> Bool {
    boolean(item, kAXEnabledAttribute) ?? true
  }

  private static func submenu(of item: AXUIElement) -> AXUIElement? {
    children(of: item).first { role(of: $0) == (kAXMenuRole as String) }
  }

  private static func openIfEmpty(_ menu: AXUIElement, byPressing opener: AXUIElement) {
    guard children(of: menu).isEmpty else { return }
    AXUIElementPerformAction(opener, kAXPressAction as CFString)
    for _ in 0..<8 where children(of: menu).isEmpty {
      Thread.sleep(forTimeInterval: 0.025)
    }
  }

  private static func children(of element: AXUIElement) -> [AXUIElement] {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success else { return [] }
    return value as? [AXUIElement] ?? []
  }

  private static func role(of element: AXUIElement) -> String? {
    string(element, kAXRoleAttribute)
  }

  private static func attribute(_ element: AXUIElement, _ name: String) -> AXUIElement? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
  }

  private static func string(_ element: AXUIElement, _ name: String) -> String? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return value as? String
  }

  private static func number(_ element: AXUIElement, _ name: String) -> Int? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return (value as? NSNumber)?.intValue
  }

  private static func boolean(_ element: AXUIElement, _ name: String) -> Bool? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
    return (value as? NSNumber)?.boolValue
  }
}
