/// One switch, from the first press to the ⌥ release: the windows it cycles through and which one is selected.
@MainActor
enum Switcher {
    private static var windows: [Window] = []
    private static var selected = 0

    /// Lists the windows for `scope`, selects the one behind the current window, and shows the panel.
    static func open(_ scope: Hotkeys.Scope) {
        windows = Window.onScreen(scope)
        selected = windows.count > 1 ? 1 : 0
        Panel.show(windows, selected: selected)
    }

    /// Moves the selection to the next window, wrapping around at the end.
    static func next() {
        guard !windows.isEmpty else { return }
        selected = (selected + 1) % windows.count
        Panel.select(selected)
    }

    /// Ends the switch and hides the panel.
    static func release() {
        Panel.hide()
        windows = []
    }
}
