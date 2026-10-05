import AppKit

/// One switch, from the first press until it closes: the windows it cycles through and which one is selected.
@MainActor
enum Switcher {
    private static var windows: [Window] = []
    private static var selected = 0
    private static var outsideClicks: Any?
    private static var number = 0

    /// Whether a switch is showing windows. It closes on ⌥ release, a click on a window,
    /// Esc, or a click outside the panel, whichever comes first.
    static var isOpen: Bool { !windows.isEmpty }

    /// Carries out what a key press asked of the switch.
    static func perform(_ action: Hotkeys.Action) {
        switch action {
        case .open(let scope, let number): open(scope, number: number)
        case .next: next()
        case .move(let direction): move(direction)
        case .cancel: cancel()
        case .release: release()
        }
    }

    /// Lists the windows for `scope`, most recently used first, selects the previous one, and shows the panel.
    ///
    /// `number` is the number the keyboard gave this switch. When there are no windows to show, the switch ends at once.
    static func open(_ scope: Hotkeys.Scope, number: Int) {
        self.number = number
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier { Recents.recordFocusedWindow(of: pid) }
        windows = Recents.sorted(Window.listed(scope))
        selected = windows.count > 1 ? 1 : 0
        Panel.show(windows, selected: selected)
        guard isOpen else { return Hotkeys.switchEnded(number) }
        outsideClicks = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { _ in
            MainActor.assumeIsolated { cancel() }
        }
    }

    /// Moves the selection to the next window, wrapping around at the end.
    static func next() {
        move(.right)
    }

    enum Direction { case left, right, up, down }

    /// Moves the selection one tile left or right, wrapping around, or one row up or down, stopping at the edges.
    ///
    /// Moving down into a shorter last row lands on its last tile when there's none directly below.
    static func move(_ direction: Direction) {
        guard !windows.isEmpty else { return }
        switch direction {
        case .left: selected = (selected - 1 + windows.count) % windows.count
        case .right: selected = (selected + 1) % windows.count
        case .up where selected - Panel.columns >= 0: selected -= Panel.columns
        case .down where selected / Panel.columns < (windows.count - 1) / Panel.columns:
            selected = min(selected + Panel.columns, windows.count - 1)
        default: return
        }
        Panel.select(selected)
    }

    /// Asks the window at `index` to close and takes it out of the switch once it has, which stays open unless no windows are left.
    ///
    /// The window is checked every 50 milliseconds for two seconds, or until this switch ends.
    /// When it's still there after that, such as when its app is asking whether to save changes, it stays in the switch.
    static func closeWindow(_ index: Int) {
        guard windows.indices.contains(index) else { return }
        let window = windows[index]
        let number = number
        window.close()
        Task {
            for _ in 0..<40 {
                guard isOpen, self.number == number else { return }
                if window.isClosed { return remove { $0.id == window.id } }
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
    }

    /// Quits the app that owns the window at `index`, the same as ⌘Q, and takes all its windows out of the switch.
    static func quitApp(_ index: Int) {
        guard windows.indices.contains(index) else { return }
        let pid = windows[index].pid
        NSRunningApplication(processIdentifier: pid)?.terminate()
        remove { $0.pid == pid }
    }

    /// Takes the windows matching `isGone` out of the switch and shows the rest, keeping the same window selected when it's still there.
    ///
    /// When no windows are left, the switch ends.
    private static func remove(where isGone: (Window) -> Bool) {
        let selectedID = windows[selected].id
        windows.removeAll(where: isGone)
        guard isOpen else { return cancel() }
        selected = windows.firstIndex { $0.id == selectedID } ?? min(selected, windows.count - 1)
        Panel.show(windows, selected: selected)
    }

    /// Ends the switch on the window at `index`, without waiting for ⌥ to be released.
    static func pick(_ index: Int) {
        selected = index
        release()
    }

    /// Ends the switch: hides the panel and focuses the selected window.
    static func release() {
        let target = windows.indices.contains(selected) ? windows[selected] : nil
        close()
        if let target {
            Recents.record(target.id)
            target.focus()
        }
    }

    /// Abandons the switch without focusing anything, leaving you where you were.
    ///
    /// A click outside the panel still reaches whatever it lands on.
    static func cancel() {
        close()
    }

    /// Hides the panel, forgets the windows, and tells the keyboard that this switch has ended.
    private static func close() {
        Panel.hide()
        windows = []
        Hotkeys.switchEnded(number)
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }
}
