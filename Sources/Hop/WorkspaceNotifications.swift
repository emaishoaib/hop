import AppKit

extension NSWorkspace {
    func onAppChange(_ name: Notification.Name, _ handle: @escaping @MainActor (pid_t) -> Void) {
        _ = notificationCenter.addObserver(forName: name, object: nil, queue: .main) { note in
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier else { return }
            MainActor.assumeIsolated { handle(pid) }
        }
    }

    var frontmostPID: pid_t? {
        frontmostApplication?.processIdentifier
    }

    var watchableApps: [NSRunningApplication] {
        runningApplications.filter { $0.activationPolicy != .prohibited }
    }
}
