import AppKit

/// A window on the current Space, as the switcher lists it.
struct Window {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String

    /// The normal app windows on screen, frontmost first.
    ///
    /// Windows under 100 points in either direction are skipped, since those are apps' helper windows,
    /// not windows you'd switch to. For `.activeApp`, only the frontmost app's windows are kept.
    @MainActor
    static func onScreen(_ scope: Hotkeys.Scope) -> [Window] {
        let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
        let ownPID = getpid()
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return entries.compactMap { entry in
            guard entry[kCGWindowLayer] as? Int == 0,
                  (entry[kCGWindowAlpha] as? Double ?? 0) > 0,
                  let bounds = (entry[kCGWindowBounds] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0 as CFDictionary) }),
                  bounds.width >= 100, bounds.height >= 100,
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

    /// What the switcher shows under this window.
    ///
    /// For a VS Code window on a file inside a git repo, this is the repo's name.
    /// Otherwise it's the window's title, or the app's name when the window has no title.
    var label: String {
        vsCodeRepoName ?? (title.isEmpty ? appName : title)
    }

    /// The name of the git repo holding the file open in this window, when this is a VS Code window.
    ///
    /// VS Code reports the open file through Accessibility. The repo is the nearest folder above it that contains `.git`.
    private var vsCodeRepoName: String? {
        var value: CFTypeRef?
        guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.microsoft.VSCode",
              let window = accessibilityWindow(in: AXUIElementCreateApplication(pid)),
              AXUIElementCopyAttributeValue(window, kAXDocumentAttribute as CFString, &value) == .success,
              let document = value as? String,
              let file = URL(string: document), file.isFileURL
        else { return nil }
        var folder = file.deletingLastPathComponent()
        while folder.path != "/" {
            if FileManager.default.fileExists(atPath: folder.appendingPathComponent(".git").path) {
                return folder.lastPathComponent
            }
            folder.deleteLastPathComponent()
        }
        return nil
    }

    /// Brings this window to the front and makes its app the active one, leaving the app's other windows where they are.
    ///
    /// The window is made its app's main window first, because activating an app brings only its main window forward.
    /// When the window can't be found through Accessibility, the app is still activated.
    func focus() {
        if let window = accessibilityWindow(in: AXUIElementCreateApplication(pid)) {
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        NSRunningApplication(processIdentifier: pid)?.activate(options: [])
    }

    /// The Accessibility element for this window, found among its app's windows by window id.
    private func accessibilityWindow(in app: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return nil }
        return windows.first { window in
            var windowID: CGWindowID = 0
            return _AXUIElementGetWindow(window, &windowID) == .success && windowID == id
        }
    }
}

/// Reads the window id behind an Accessibility window element.
///
/// This is a private macOS function, but the only reliable way to tie an Accessibility window
/// to the window id the window list reports. It has been stable for over a decade.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ id: UnsafeMutablePointer<CGWindowID>) -> AXError
