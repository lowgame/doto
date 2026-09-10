import AppKit
import DotoCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Prevent app from showing in Dock (menu bar accessory mode)
        NSApp.setActivationPolicy(.accessory)

        // Initialize status bar item and panel
        DotoPanelController.shared.setup()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
