import AppKit
import ServiceManagement

let app = NSApplication.shared
if SMAppService.mainApp.status == .notRegistered { try? SMAppService.mainApp.register() }
CGRequestScreenCaptureAccess()
Hotkeys.start()
app.run()
