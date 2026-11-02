import AppKit

extension AXUIElement {
    private static let shortAnswerTimeout: Float = 0.25

    static func appWithShortTimeout(_ pid: pid_t) -> AXUIElement {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, shortAnswerTimeout)
        return app
    }

    var windowID: CGWindowID? {
        var id: CGWindowID = 0
        return _AXUIElementGetWindow(self, &id) == .success ? id : nil
    }

    var windows: [AXUIElement]? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, kAXWindowsAttribute as CFString, &value) == .success else { return nil }
        return value as? [AXUIElement]
    }
}
