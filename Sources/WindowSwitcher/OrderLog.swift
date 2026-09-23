import os

/// Temporary logging of the on-screen window order, to catch when an app's other windows jump forward after a switch.
///
/// Read it with: log show --last 10m --predicate 'subsystem == "com.mustafa.window-switcher"'
@MainActor
enum OrderLog {
    private static let logger = Logger(subsystem: "com.mustafa.window-switcher", category: "order")

    /// Logs `moment` with the eight frontmost windows on screen, frontmost first.
    static func log(_ moment: String) {
        let order = Window.onScreen(.allApps).prefix(8).map { "\($0.appName) #\($0.id) \"\($0.title)\"" }.joined(separator: " | ")
        logger.log("\(moment, privacy: .public): \(order, privacy: .public)")
    }
}
