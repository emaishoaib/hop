import AppKit

/// The windows you've focused, most recent first, so a switch can list them in the order you used them.
///
/// It follows each app's focused window through Accessibility notifications, so it sees a focus change
/// however it happened: ⌘Tab, a click, the Dock, or the switcher itself.
@MainActor
enum Recents {
    private static var order: [CGWindowID] = []
    private static var observers: [pid_t: AXObserver] = [:]

    /// Starts following focus in every running app, and in each app as it becomes active.
    static func start() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
            watch(app.processIdentifier)
        }
        let center = NSWorkspace.shared.notificationCenter
        _ = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated {
                watch(pid)
                recordFocusedWindow(of: pid)
            }
        }
        _ = center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { unwatch(pid) }
        }
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier { recordFocusedWindow(of: pid) }
    }

    /// Moves the window `id` to the front of the order, keeping the 100 most recent.
    static func record(_ id: CGWindowID) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
        if order.count > 100 { order.removeLast() }
    }

    /// `windows` with the ones you've used first, most recent first, and the rest after them in their original order.
    static func sorted(_ windows: [Window]) -> [Window] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return windows.enumerated()
            .sorted { (rank[$0.element.id] ?? Int.max, $0.offset) < (rank[$1.element.id] ?? Int.max, $1.offset) }
            .map(\.element)
    }

    /// Starts following the focused window of the app `pid`, unless it's already followed or not ready yet.
    ///
    /// An app that isn't ready is tried again the next time it becomes active.
    private static func watch(_ pid: pid_t) {
        guard pid != getpid(), observers[pid] == nil else { return }
        var observer: AXObserver?
        AXObserverCreate(pid, { _, window, _, _ in
            var id: CGWindowID = 0
            guard _AXUIElementGetWindow(window, &id) == .success else { return }
            let windowID = id
            MainActor.assumeIsolated { Recents.record(windowID) }
        }, &observer)
        guard let observer,
              AXObserverAddNotification(observer, AXUIElementCreateApplication(pid), kAXFocusedWindowChangedNotification as CFString, nil) == .success
        else { return }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private static func unwatch(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    /// Records the window that has focus in the app `pid`, which is how a switch to a whole app gets noticed.
    ///
    /// The switcher also calls it as it opens, to catch a window that appeared while its app was still launching.
    static func recordFocusedWindow(of pid: pid_t) {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return }
        var id: CGWindowID = 0
        if _AXUIElementGetWindow(value as! AXUIElement, &id) == .success { record(id) }
    }
}
