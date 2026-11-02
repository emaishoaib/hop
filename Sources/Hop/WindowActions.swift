import AppKit

extension Window {
    var isClosed: Bool {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return true }
        guard let windows = AXUIElement.appWithShortTimeout(pid).windows else { return false }
        return !windows.contains { $0.windowID == id }
    }

    func focus() {
        let app = NSRunningApplication(processIdentifier: pid)
        app?.unhide()
        if let accessibilityWindow {
            AXUIElementSetAttributeValue(accessibilityWindow, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(accessibilityWindow, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(accessibilityWindow, kAXRaiseAction as CFString)
        }
        var process = ProcessSerialNumber()
        guard GetProcessForPID(pid, &process) == noErr,
              SetFrontProcessWithOptions(&process, OptionBits(kSetFrontProcessFrontWindowOnly)) == noErr
        else {
            app?.activate(options: [])
            return
        }
    }

    func close() {
        var button: CFTypeRef?
        guard let accessibilityWindow,
              AXUIElementCopyAttributeValue(accessibilityWindow, kAXCloseButtonAttribute as CFString, &button) == .success,
              let button, CFGetTypeID(button) == AXUIElementGetTypeID()
        else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }
}
