import AppKit
import ApplicationServices

struct AppWindow {
  let app: NSRunningApplication
  let element: AXUIElement

  var title: String {
    string(kAXTitleAttribute)
  }

  var isStandard: Bool {
    string(kAXSubroleAttribute) == kAXStandardWindowSubrole
  }

  var isMinimized: Bool {
    bool(kAXMinimizedAttribute)
  }

  var frame: CGRect {
    CGRect(origin: point(kAXPositionAttribute), size: size(kAXSizeAttribute))
  }

  func move(to target: CGRect) {
    write(point: target.origin, to: kAXPositionAttribute)
    write(size: target.size, to: kAXSizeAttribute)
    write(point: target.origin, to: kAXPositionAttribute)
  }

  func unminimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
  }

  private func stored(_ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    return value
  }

  private func string(_ attribute: String) -> String {
    stored(attribute) as? String ?? ""
  }

  private func bool(_ attribute: String) -> Bool {
    stored(attribute) as? Bool ?? false
  }

  private func point(_ attribute: String) -> CGPoint {
    var point = CGPoint.zero
    guard let value = stored(attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return point }
    AXValueGetValue(value as! AXValue, .cgPoint, &point)
    return point
  }

  private func size(_ attribute: String) -> CGSize {
    var size = CGSize.zero
    guard let value = stored(attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return size }
    AXValueGetValue(value as! AXValue, .cgSize, &size)
    return size
  }

  private func write(point: CGPoint, to attribute: String) {
    var point = point
    guard let value = AXValueCreate(.cgPoint, &point) else { return }
    AXUIElementSetAttributeValue(element, attribute as CFString, value)
  }

  private func write(size: CGSize, to attribute: String) {
    var size = size
    guard let value = AXValueCreate(.cgSize, &size) else { return }
    AXUIElementSetAttributeValue(element, attribute as CFString, value)
  }
}
