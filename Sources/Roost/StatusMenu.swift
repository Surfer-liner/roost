import AppKit
import RoostKit
import ServiceManagement

final class StatusMenu: NSObject, NSMenuDelegate {
  private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
  private let store = LayoutStore()
  private let displayWatcher = DisplayWatcher()
  private let savedLayoutSummary = NSMenuItem()
  private let autoRestoreToggle = NSMenuItem()
  private let launchAtLoginToggle = NSMenuItem()
  private var restorer: LayoutRestorer?

  override init() {
    super.init()
    showIconInMenuBar()
    statusItem.menu = buildMenu()
    watchForDisplayChanges()
  }

  private func showIconInMenuBar() {
    let image = NSImage(size: NSSize(width: 18, height: 16), flipped: false) { rect in
      guard let context = NSGraphicsContext.current?.cgContext else { return false }
      IconArtwork.drawMenuBarGlyph(in: context, bounds: rect)
      return true
    }
    image.isTemplate = true
    statusItem.button?.image = image
    statusItem.button?.imagePosition = .imageLeading
  }

  private func buildMenu() -> NSMenu {
    let menu = NSMenu()
    menu.delegate = self
    menu.addItem(actionItem("Save Layout", #selector(saveCurrentLayout), "s"))
    menu.addItem(actionItem("Restore Layout", #selector(restoreSavedLayout), "r"))
    menu.addItem(.separator())
    menu.addItem(savedLayoutSummary)
    menu.addItem(.separator())
    configureToggle(autoRestoreToggle, "Auto-Restore on Reconnect", #selector(toggleAutoRestore))
    configureToggle(launchAtLoginToggle, "Launch at Login", #selector(toggleLaunchAtLogin))
    menu.addItem(autoRestoreToggle)
    menu.addItem(launchAtLoginToggle)
    menu.addItem(.separator())
    menu.addItem(actionItem("Quit Roost", #selector(quitRoost), "q"))
    return menu
  }

  private func actionItem(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
    item.keyEquivalentModifierMask = []
    item.target = self
    return item
  }

  private func configureToggle(_ item: NSMenuItem, _ title: String, _ action: Selector) {
    item.title = title
    item.action = action
    item.target = self
  }

  private func watchForDisplayChanges() {
    displayWatcher.onDisplaysSettled = { [weak self] fingerprint in
      self?.autoRestoreIfWanted(for: fingerprint)
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    savedLayoutSummary.title = savedLayoutDescription()
    autoRestoreToggle.state = autoRestoreEnabled ? .on : .off
    launchAtLoginToggle.state = SMAppService.mainApp.status == .enabled ? .on : .off
  }

  @objc private func saveCurrentLayout() {
    guard ensureAccessibilityAccess() else { return }
    guard !NSScreen.screens.isEmpty else { return }
    let layout = LayoutCapturer.captureCurrentLayout()
    flash(store.save(layout) ? "Saved \(layout.windows.count)" : "Save failed")
  }

  @objc private func restoreSavedLayout() {
    guard ensureAccessibilityAccess() else { return }
    guard !NSScreen.screens.isEmpty else { return }
    guard let layout = store.layout(for: DisplayFingerprint.current()) else {
      explainThereIsNothingToRestore()
      return
    }
    startRestore(of: layout)
  }

  @objc private func toggleAutoRestore() {
    autoRestoreEnabled.toggle()
  }

  @objc private func toggleLaunchAtLogin() {
    let roost = SMAppService.mainApp
    do {
      if roost.status == .enabled {
        try roost.unregister()
      } else {
        try roost.register()
      }
    } catch {
      explainLoginItemFailed()
    }
  }

  @objc private func quitRoost() {
    NSApp.terminate(nil)
  }

  private var autoRestoreEnabled: Bool {
    get { UserDefaults.standard.bool(forKey: "autoRestoreOnReconnect") }
    set { UserDefaults.standard.set(newValue, forKey: "autoRestoreOnReconnect") }
  }

  private func autoRestoreIfWanted(for fingerprint: String) {
    guard autoRestoreEnabled, AccessibilityPermission.isGranted else { return }
    guard let layout = store.layout(for: fingerprint) else { return }
    startRestore(of: layout)
  }

  private func startRestore(of layout: Layout) {
    guard restorer == nil else { return }
    restorer = LayoutRestorer(layout: layout) { [weak self] placed, saved in
      self?.restorer = nil
      self?.flash(placed == saved ? "Restored \(saved)" : "Restored \(placed)/\(saved)")
    }
    restorer?.restore()
  }

  private func savedLayoutDescription() -> String {
    guard let layout = store.layout(for: DisplayFingerprint.current()) else {
      return "Nothing saved for \(displaySetupName()) yet"
    }
    return "\(layout.windows.count) windows saved for \(displaySetupName()) \(relativeAge(of: layout))"
  }

  private func displaySetupName() -> String {
    let displayCount = NSScreen.screens.count
    return displayCount == 1 ? "this single display" : "this \(displayCount)-display setup"
  }

  private func relativeAge(of layout: Layout) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: layout.savedAt, relativeTo: Date())
  }

  private func flash(_ message: String) {
    statusItem.button?.title = " \(message)"
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
      self?.statusItem.button?.title = ""
    }
  }

  private func ensureAccessibilityAccess() -> Bool {
    if AccessibilityPermission.isGranted { return true }
    explainHowToGrantAccess()
    return false
  }

  private func explainHowToGrantAccess() {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Roost needs Accessibility access"
    alert.informativeText = "macOS only lets trusted apps move other apps' windows. Enable Roost in System Settings → Privacy & Security → Accessibility, then try again."
    alert.addButton(withTitle: "Open System Settings")
    alert.addButton(withTitle: "Later")
    if alert.runModal() == .alertFirstButtonReturn {
      openAccessibilitySettings()
    }
  }

  private func openAccessibilitySettings() {
    guard let pane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
    NSWorkspace.shared.open(pane)
  }

  private func explainThereIsNothingToRestore() {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Nothing saved for this display setup"
    alert.informativeText = "Arrange your windows the way you like them, then click Save Layout. Roost keeps a separate layout for every display setup."
    alert.runModal()
  }

  private func explainLoginItemFailed() {
    NSApp.activate(ignoringOtherApps: true)
    let alert = NSAlert()
    alert.messageText = "Could not change Launch at Login"
    alert.informativeText = "macOS refused the change. This usually means Roost is not running from /Applications. Move Roost to your Applications folder and try again."
    alert.runModal()
  }
}
