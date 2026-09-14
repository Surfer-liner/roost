import AppKit
import RoostKit

if SelfTest.wantsToRun() {
  SelfTest.runAndExit()
}

let app = NSApplication.shared
let roost = RoostApp()
app.delegate = roost
app.setActivationPolicy(.accessory)
app.run()
