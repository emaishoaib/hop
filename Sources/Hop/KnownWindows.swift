import AppKit

/// Each app's windows as the app last reported them through Accessibility, kept up to date ahead of time
/// so a switch never waits for an app to answer.
///
/// An app is asked again whenever it reports a window being created, minimized or brought back from the Dock,
/// and whenever it's launched, activated, hidden or shown. The asking happens off the main thread,
/// so an app that's slow to answer only holds up its own entry.
@MainActor
enum KnownWindows {
    private static var reported: [pid_t: [ReportedWindow]] = [:]
    private static let queue = DispatchQueue(label: "Hop known windows", qos: .userInitiated)

    /// The windows the app `pid` last reported, or nil when it hasn't answered or reported no windows at all.
    static func of(_ pid: pid_t) -> [ReportedWindow]? {
        reported[pid]
    }

    /// Starts keeping the windows of every running app, and of each app as it launches.
    ///
    /// Asks the watcher for window changes, so it must be called before the watcher starts.
    static func start() {
        for notification in [kAXWindowCreatedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
            Watcher.on(notification) { app, _ in refresh(app) }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            _ = center.addObserver(forName: name, object: nil, queue: .main) { note in
                guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
                MainActor.assumeIsolated { refresh(pid) }
            }
        }
        _ = center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { reported[pid] = nil }
        }
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
            refresh(app.processIdentifier)
        }
    }

    /// Asks the app `pid` for its windows off the main thread, and keeps the answer once it arrives.
    ///
    /// Apps are asked one at a time, in the order their changes came in, so a later answer always replaces an earlier one.
    private static func refresh(_ pid: pid_t) {
        queue.async {
            let windows = ReportedWindow.windows(of: pid)
            DispatchQueue.main.async {
                MainActor.assumeIsolated { reported[pid] = windows }
            }
        }
    }
}

/// One of an app's windows, as the app reports it through Accessibility.
///
/// A prompt, such as one asking whether to save changes, is either attached to a window or modal,
/// meaning the app does nothing else until it's answered. Accessibility reports an attached prompt
/// as part of its window rather than as a window, and says which windows are modal.
struct ReportedWindow {
    let id: CGWindowID
    let isModal: Bool
    let isMinimized: Bool
    let title: String

    /// The windows the app `pid` reports, with each window's details read in a single request.
    ///
    /// This is nil when the app doesn't answer within a quarter of a second or reports no windows at all.
    static func windows(of pid: pid_t) -> [ReportedWindow]? {
        var value: CFTypeRef?
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty
        else { return nil }
        let attributes = [kAXModalAttribute, kAXMinimizedAttribute, kAXTitleAttribute]
        return windows.compactMap { window in
            var id: CGWindowID = 0
            var values: CFArray?
            guard _AXUIElementGetWindow(window, &id) == .success else { return nil }
            AXUIElementCopyMultipleAttributeValues(window, attributes as CFArray, [], &values)
            let answers = values as? [Any] ?? []
            guard answers.count == attributes.count else { return ReportedWindow(id: id, isModal: false, isMinimized: false, title: "") }
            return ReportedWindow(id: id, isModal: answers[0] as? Bool == true, isMinimized: answers[1] as? Bool == true, title: answers[2] as? String ?? "")
        }
    }
}
