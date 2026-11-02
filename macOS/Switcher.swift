import AppKit

@MainActor
final class Switcher {
    static let shared = Switcher()

    private static let closeChecks = 40
    private static let closeCheckInterval = Duration.milliseconds(50)

    private struct OpenSwitch {
        let number: Int
        var windows: [Window]
        var selected: Int
        var outsideClicks: Any?
    }

    private var current: OpenSwitch?

    func perform(_ action: SwitchAction) {
        switch action {
        case .open(let scope, let number): open(scope, number: number)
        case .next: move(.right)
        case .move(let direction): move(direction)
        case .cancel: close()
        case .release: release()
        }
    }

    func closeWindow(at index: Int) {
        guard let current, current.windows.indices.contains(index) else { return }
        let window = current.windows[index]
        let number = current.number
        window.close()
        Task {
            for _ in 0..<Self.closeChecks {
                guard self.current?.number == number else { return }
                if window.isClosed { return remove { $0.id == window.id } }
                try? await Task.sleep(for: Self.closeCheckInterval)
            }
        }
    }

    func quitApp(at index: Int) {
        guard let current, current.windows.indices.contains(index) else { return }
        let pid = current.windows[index].pid
        NSRunningApplication(processIdentifier: pid)?.terminate()
        remove { $0.pid == pid }
    }

    func pick(at index: Int) {
        current?.selected = index
        release()
    }

    private func open(_ scope: SwitchScope, number: Int) {
        if let pid = NSWorkspace.shared.frontmostPID { Recents.shared.recordFocusedWindow(of: pid) }
        let windows = Recents.shared.sorted(Window.listed(scope))
        guard !windows.isEmpty else { return Hotkeys.shared.switchEnded(number) }
        let selected = windows.count > 1 ? 1 : 0
        current = OpenSwitch(number: number, windows: windows, selected: selected)
        Panel.shared.show(windows, selected: selected)
        current?.outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    private func move(_ direction: SwitchDirection) {
        guard let current else { return }
        let count = current.windows.count
        let columns = Panel.shared.columns
        let selected = current.selected
        let moved: Int? = switch direction {
        case .left: (selected - 1 + count) % count
        case .right: (selected + 1) % count
        case .up where selected - columns >= 0: selected - columns
        case .down where selected / columns < (count - 1) / columns: min(selected + columns, count - 1)
        default: nil
        }
        guard let moved else { return }
        self.current?.selected = moved
        Panel.shared.select(moved)
    }

    private func remove(where isGone: (Window) -> Bool) {
        guard var updated = current else { return }
        let selectedID = updated.windows[updated.selected].id
        updated.windows.removeAll(where: isGone)
        guard !updated.windows.isEmpty else { return close() }
        updated.selected = updated.windows.firstIndex { $0.id == selectedID } ?? min(updated.selected, updated.windows.count - 1)
        current = updated
        Panel.shared.show(updated.windows, selected: updated.selected)
    }

    private func release() {
        guard let current else { return }
        let target = current.windows.indices.contains(current.selected) ? current.windows[current.selected] : nil
        close()
        guard let target else { return }
        Recents.shared.record(target.id)
        target.focus()
    }

    private func close() {
        guard let current else { return }
        Panel.shared.hide()
        Hotkeys.shared.switchEnded(current.number)
        if let outsideClicks = current.outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        self.current = nil
    }
}
