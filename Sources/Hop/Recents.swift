import AppKit

@MainActor
final class Recents {
    static let shared = Recents()

    private static let remembered = 100
    private static let focusRetries = 20
    private static let focusRetryInterval = Duration.milliseconds(100)

    private var order: [CGWindowID] = []

    func start() {
        Watcher.shared.on(kAXFocusedWindowChangedNotification) { [self] _, window in
            if let window { record(window) }
        }
        NSWorkspace.shared.onAppChange(NSWorkspace.didActivateApplicationNotification) { [self] in
            recordFocusedWindowOfNewlyActiveApp($0)
        }
        if let pid = NSWorkspace.shared.frontmostPID { recordFocusedWindow(of: pid) }
    }

    func record(_ id: CGWindowID) {
        order.removeAll { $0 == id }
        order.insert(id, at: 0)
        if order.count > Self.remembered { order.removeLast() }
    }

    func sorted(_ windows: [Window]) -> [Window] {
        let rank = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        return windows.enumerated()
            .sorted { (rank[$0.element.id] ?? Int.max, $0.offset) < (rank[$1.element.id] ?? Int.max, $1.offset) }
            .map(\.element)
    }

    @discardableResult
    func recordFocusedWindow(of pid: pid_t) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID(),
              let id = (value as! AXUIElement).windowID
        else { return false }
        record(id)
        return true
    }

    private func recordFocusedWindowOfNewlyActiveApp(_ pid: pid_t) {
        guard !recordFocusedWindow(of: pid) else { return }
        Task {
            for _ in 0..<Self.focusRetries {
                try? await Task.sleep(for: Self.focusRetryInterval)
                guard NSWorkspace.shared.frontmostPID == pid, !recordFocusedWindow(of: pid) else { return }
            }
        }
    }
}
