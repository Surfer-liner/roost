import AppKit
import RoostKit

if CommandActions.wantsToRun() {
  CommandActions.runAndExit()
}

let app = NSApplication.shared
let roost = RoostApp()
app.delegate = roost
app.setActivationPolicy(.accessory)
app.run()
