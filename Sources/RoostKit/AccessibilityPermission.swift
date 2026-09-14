import ApplicationServices

public enum AccessibilityPermission {
  public static var isGranted: Bool {
    AXIsProcessTrusted()
  }

  public static func askIfNeeded() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
  }
}
