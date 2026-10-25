import AppKit

/// Follows what happens in every app through Accessibility notifications, and passes each one on to whoever asked for it.
///
/// Each app gets one observer, subscribed to every notification asked for with `on`.
@MainActor
enum Watcher {
    private static var observers: [pid_t: AXObserver] = [:]
    private static var retrying: Set<pid_t> = []
    private static var handlers: [String: [@MainActor (pid_t, CGWindowID?) -> Void]] = [:]

    /// Calls `handle` each time any app sends `notification`, with the app and, when the notification
    /// came from a window, that window's id.
    ///
    /// Only notifications asked for before `start` are followed.
    static func on(_ notification: String, _ handle: @escaping @MainActor (pid_t, CGWindowID?) -> Void) {
        handlers[notification, default: []].append(handle)
    }

    /// Starts following every running app, and each app as it becomes active.
    static func start() {
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited {
            watch(app.processIdentifier)
        }
        let center = NSWorkspace.shared.notificationCenter
        _ = center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { watch(pid) }
        }
        _ = center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { unwatch(pid) }
        }
    }

    /// Starts following the app `pid`, unless it's already followed or being retried.
    ///
    /// An app that has only just launched may not be ready yet. It's tried again every tenth of a second
    /// for two seconds, and after that the next time it becomes active.
    private static func watch(_ pid: pid_t) {
        guard pid != getpid(), observers[pid] == nil, !retrying.contains(pid) else { return }
        retry(pid, attemptsLeft: 20)
    }

    /// Tries to follow the app `pid`, and schedules another try while it fails and `attemptsLeft` is above zero.
    private static func retry(_ pid: pid_t, attemptsLeft: Int) {
        guard !subscribe(pid), attemptsLeft > 0 else {
            retrying.remove(pid)
            return
        }
        retrying.insert(pid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            MainActor.assumeIsolated { retry(pid, attemptsLeft: attemptsLeft - 1) }
        }
    }

    /// Subscribes to every notification asked for in the app `pid`, and returns whether any of them worked.
    private static func subscribe(_ pid: pid_t) -> Bool {
        var observer: AXObserver?
        AXObserverCreate(pid, { _, element, notification, _ in
            var pid: pid_t = 0
            var id: CGWindowID = 0
            AXUIElementGetPid(element, &pid)
            let app = pid
            let window = _AXUIElementGetWindow(element, &id) == .success ? id : nil
            let name = notification as String
            MainActor.assumeIsolated { Watcher.deliver(name, app: app, window: window) }
        }, &observer)
        let element = AXUIElementCreateApplication(pid)
        guard let observer,
              handlers.keys.map({ AXObserverAddNotification(observer, element, $0 as CFString, nil) }).contains(.success)
        else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
        return true
    }

    private static func unwatch(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    /// Passes `notification` from the app `app` on to everyone who asked for it.
    private static func deliver(_ notification: String, app: pid_t, window: CGWindowID?) {
        for handle in handlers[notification] ?? [] { handle(app, window) }
    }
}
