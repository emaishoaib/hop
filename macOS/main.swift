import AppKit
import ServiceManagement

let app = NSApplication.shared
if SMAppService.mainApp.status == .notRegistered { try? SMAppService.mainApp.register() }
CGRequestScreenCaptureAccess()
AppUpdater.shared.start()
Accessibility.whenTrusted {
    Hotkeys.shared.start()
    Recents.shared.start()
    KnownWindows.shared.start()
    Watcher.shared.start()
}
app.run()
