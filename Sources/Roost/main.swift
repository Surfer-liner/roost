import AppKit

let app = NSApplication.shared
let roost = RoostApp()
app.delegate = roost
app.setActivationPolicy(.accessory)
app.run()
