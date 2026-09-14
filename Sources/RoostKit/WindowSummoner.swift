import AppKit
import Carbon.HIToolbox

public enum WindowSummoner {
  private static let commandN: CGKeyCode = CGKeyCode(kVK_ANSI_N)

  public static func requestOneMoreWindow(from app: NSRunningApplication) {
    app.activate(options: [.activateIgnoringOtherApps])
    guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
    guard
      let keyDown = CGEvent(keyboardEventSource: source, virtualKey: commandN, keyDown: true),
      let keyUp = CGEvent(keyboardEventSource: source, virtualKey: commandN, keyDown: false)
    else { return }
    keyDown.flags = .maskCommand
    keyUp.flags = .maskCommand
    keyDown.postToPid(app.processIdentifier)
    keyUp.postToPid(app.processIdentifier)
  }
}
