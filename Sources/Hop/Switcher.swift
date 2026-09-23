/// One switch, from the first press to the ⌥ release: the windows it cycles through and which one is selected.
@MainActor
enum Switcher {
    private static var windows: [Window] = []
    private static var selected = 0

    /// Whether a switch is showing windows. It closes on ⌥ release or on a click, whichever comes first.
    static var isOpen: Bool { !windows.isEmpty }

    /// Lists the windows for `scope`, most recently used first, selects the previous one, and shows the panel.
    static func open(_ scope: Hotkeys.Scope) {
        windows = Recents.sorted(Window.onScreen(scope))
        selected = windows.count > 1 ? 1 : 0
        Panel.show(windows, selected: selected)
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

    /// Selects the window at `index`, as the mouse moves over its tile.
    static func select(_ index: Int) {
        guard index != selected else { return }
        selected = index
        Panel.select(selected)
    }

    /// Ends the switch on the window at `index`, without waiting for ⌥ to be released.
    static func pick(_ index: Int) {
        selected = index
        release()
    }

    /// Ends the switch: hides the panel and focuses the selected window.
    static func release() {
        Panel.hide()
        if windows.indices.contains(selected) {
            Recents.record(windows[selected].id)
            windows[selected].focus()
        }
        windows = []
    }
}
