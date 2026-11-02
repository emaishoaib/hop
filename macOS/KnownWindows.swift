import AppKit

@MainActor
final class KnownWindows {
    static let shared = KnownWindows()

    private var reported: [pid_t: [ReportedWindow]] = [:]
    private let requests: AsyncStream<pid_t>.Continuation

    private init() {
        let (stream, requests) = AsyncStream.makeStream(of: pid_t.self)
        self.requests = requests
        Task.detached(priority: .userInitiated) { [self] in
            for await pid in stream {
                let windows = ReportedWindow.windows(of: pid)
                await keep(windows, for: pid)
            }
        }
    }

    func windows(of pid: pid_t) -> [ReportedWindow]? {
        reported[pid]
    }

    func start() {
        for notification in [kAXWindowCreatedNotification, kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification] {
            Watcher.shared.on(notification) { [self] app, _ in refresh(app) }
        }
        let workspace = NSWorkspace.shared
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.didHideApplicationNotification, NSWorkspace.didUnhideApplicationNotification] {
            workspace.onAppChange(name) { [self] in refresh($0) }
        }
        workspace.onAppChange(NSWorkspace.didTerminateApplicationNotification) { [self] in reported[$0] = nil }
        for app in workspace.watchableApps {
            refresh(app.processIdentifier)
        }
    }

    private func refresh(_ pid: pid_t) {
        requests.yield(pid)
    }

    private func keep(_ windows: [ReportedWindow]?, for pid: pid_t) {
        reported[pid] = windows
    }
}
