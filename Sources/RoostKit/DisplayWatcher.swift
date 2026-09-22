import AppKit

public final class DisplayWatcher: NSObject {
  public var onDisplaysSettled: ((String) -> Void)?
  private var lastFingerprint: String?
  private var settleTimer: Timer?

  override public init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(displaysChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
    waitForDisplaysToSettle()
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func displaysChanged() {
    waitForDisplaysToSettle()
  }

  private func waitForDisplaysToSettle() {
    settleTimer?.invalidate()
    settleTimer = Timer.scheduledTimer(
      timeInterval: 2.5,
      target: self,
      selector: #selector(displaysSettled),
      userInfo: nil,
      repeats: false
    )
  }

  @objc private func displaysSettled() {
    let fingerprint = DisplayFingerprint.current()
    guard fingerprint != lastFingerprint else { return }
    lastFingerprint = fingerprint
    onDisplaysSettled?(fingerprint)
  }
}
