import AppKit

@MainActor
final class Watcher {
    static let shared = Watcher()

    private static let retries = 20
    private static let retryInterval = Duration.milliseconds(100)

    private let subscriber = Subscriber()
    private var observers: [pid_t: AXObserver] = [:]
    private var retrying: Set<pid_t> = []
    private var handlers: [String: [@MainActor (pid_t, CGWindowID?) -> Void]] = [:]

    func on(_ notification: String, _ handle: @escaping @MainActor (pid_t, CGWindowID?) -> Void) {
        handlers[notification, default: []].append(handle)
    }

    func start() {
        for app in NSWorkspace.shared.watchableApps {
            watch(app.processIdentifier)
        }
        NSWorkspace.shared.onAppChange(NSWorkspace.didActivateApplicationNotification) { [self] in watch($0) }
        NSWorkspace.shared.onAppChange(NSWorkspace.didTerminateApplicationNotification) { [self] in unwatch($0) }
    }

    fileprivate func deliver(_ notification: String, app: pid_t, window: CGWindowID?) {
        for handle in handlers[notification] ?? [] { handle(app, window) }
    }

    private func watch(_ pid: pid_t) {
        guard pid != getpid(), observers[pid] == nil, !retrying.contains(pid) else { return }
        retrying.insert(pid)
        let notifications = Array(handlers.keys)
        Task {
            defer { retrying.remove(pid) }
            for _ in 0...Self.retries {
                if let observer = await subscriber.subscribe(pid, to: notifications) {
                    observers[pid] = observer
                    return
                }
                try? await Task.sleep(for: Self.retryInterval)
            }
        }
    }

    private func unwatch(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}

private actor Subscriber {
    func subscribe(_ pid: pid_t, to notifications: [String]) -> sending AXObserver? {
        var observer: AXObserver?
        AXObserverCreate(pid, { _, element, notification, _ in
            var pid: pid_t = 0
            AXUIElementGetPid(element, &pid)
            let app = pid
            let window = element.windowID
            let name = notification as String
            MainActor.assumeIsolated { Watcher.shared.deliver(name, app: app, window: window) }
        }, &observer)
        let element = AXUIElement.appWithShortTimeout(pid)
        guard let observer,
              notifications.map({ AXObserverAddNotification(observer, element, $0 as CFString, nil) }).contains(.success)
        else { return nil }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        return observer
    }
}
