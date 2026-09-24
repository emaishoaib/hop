import AppKit

/// One switch, from the first press until it closes: the windows it cycles through and which one is selected.
@MainActor
enum Switcher {
    private static var windows: [Window] = []
    private static var selected = 0
    private static var outsideClicks: Any?

    /// Whether a switch is showing windows. It closes on ⌥ release, a click on a window,
    /// Esc, or a click outside the panel, whichever comes first.
    static var isOpen: Bool { !windows.isEmpty }

    /// Lists the windows for `scope`, most recently used first, selects the previous one, and shows the panel.
    static func open(_ scope: Hotkeys.Scope) {
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier { Recents.recordFocusedWindow(of: pid) }
        windows = Recents.sorted(Window.onScreen(scope))
        selected = windows.count > 1 ? 1 : 0
        Panel.show(windows, selected: selected)
        guard isOpen else { return }
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
    static func move(_ direction: Direction) {
        guard !windows.isEmpty else { return }
        switch direction {
        case .left: selected = (selected - 1 + windows.count) % windows.count
        case .right: selected = (selected + 1) % windows.count
        case .up where selected - Panel.columns >= 0: selected -= Panel.columns
        case .down where selected + Panel.columns < windows.count: selected += Panel.columns
        default: return
        }
        Panel.select(selected)
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

    private static func close() {
        Panel.hide()
        windows = []
        if let outsideClicks { NSEvent.removeMonitor(outsideClicks) }
        outsideClicks = nil
    }
}
