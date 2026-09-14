import AppKit

final class DisplayWatcher: NSObject {
  var onDisplaysSettled: ((String) -> Void)?
  private var lastFingerprint = DisplayFingerprint.current()
  private var settleTimer: Timer?

  override init() {
    super.init()
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(displaysChanged),
      name: NSApplication.didChangeScreenParametersNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  @objc private func displaysChanged() {
    settleTimer?.invalidate()
    settleTimer = Timer.scheduledTimer(
      timeInterval: 2,
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
