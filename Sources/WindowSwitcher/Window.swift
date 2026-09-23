import AppKit

/// A window on the current Space, as the switcher lists it.
struct Window {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String

    /// The normal app windows on screen, frontmost first.
    ///
    /// For `.activeApp`, only the frontmost app's windows are kept.
    @MainActor
    static func onScreen(_ scope: Hotkeys.Scope) -> [Window] {
        let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
        let ownPID = getpid()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return entries.compactMap { entry in
            guard entry[kCGWindowLayer] as? Int == 0,
                  (entry[kCGWindowAlpha] as? Double ?? 0) > 0,
                  let id = entry[kCGWindowNumber] as? CGWindowID,
                  let pid = entry[kCGWindowOwnerPID] as? pid_t,
                  pid != ownPID,
                  scope == .allApps || pid == frontmostPID
            else { return nil }
            return Window(
                id: id,
                pid: pid,
                appName: entry[kCGWindowOwnerName] as? String ?? "",
                title: entry[kCGWindowName] as? String ?? ""
            )
        }
    }
}
