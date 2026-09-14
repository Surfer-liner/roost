import ApplicationServices

enum AccessibilityPermission {
  static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  static func askIfNeeded() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
  }
}
