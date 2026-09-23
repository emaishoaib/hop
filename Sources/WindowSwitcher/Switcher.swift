/// One switch, from the first press to the ⌥ release: the windows it cycles through and which one is selected.
@MainActor
enum Switcher {
    private static var windows: [Window] = []
    private static var selected = 0

    /// Lists the windows for `scope` and selects the one behind the current window.
    static func open(_ scope: Hotkeys.Scope) {
        windows = Window.onScreen(scope)
        selected = windows.count > 1 ? 1 : 0
        for (index, window) in windows.enumerated() {
            print("\(index): \(window.appName) - \(window.title)")
        }
        printSelection()
    }

    /// Moves the selection to the next window, wrapping around at the end.
    static func next() {
        guard !windows.isEmpty else { return }
        selected = (selected + 1) % windows.count
        printSelection()
    }

    /// Ends the switch.
    static func release() {
        printSelection()
        windows = []
    }

    private static func printSelection() {
        guard windows.indices.contains(selected) else { return print("selected: none") }
        print("selected: \(selected)")
    }
}
