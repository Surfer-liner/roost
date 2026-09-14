import AppKit
import ApplicationServices

public struct AppWindow: MatchableWindow {
  public let app: NSRunningApplication
  let element: AXUIElement

  public var appBundleID: String {
    app.bundleIdentifier ?? ""
  }

  public var title: String {
    string(kAXTitleAttribute)
  }

  public var isStandard: Bool {
    string(kAXSubroleAttribute) == kAXStandardWindowSubrole
  }

  public var isMinimized: Bool {
    bool(kAXMinimizedAttribute)
  }

  public var isFullScreen: Bool {
    bool("AXFullScreen")
  }

  public var isRestorable: Bool {
    isStandard || isMinimized
  }

  public func setFullScreen(_ fullScreen: Bool) {
    AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, fullScreen ? kCFBooleanTrue : kCFBooleanFalse)
  }

  public var frame: CGRect {
    CGRect(origin: point(kAXPositionAttribute), size: size(kAXSizeAttribute))
  }

  public func move(to target: CGRect) {
    write(point: target.origin, to: kAXPositionAttribute)
    write(size: target.size, to: kAXSizeAttribute)
    write(point: target.origin, to: kAXPositionAttribute)
  }

  public func minimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
  }

  public func unminimize() {
    AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
  }

  public func close() {
    guard let button = stored(kAXCloseButtonAttribute), CFGetTypeID(button) == AXUIElementGetTypeID() else { return }
    AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
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
