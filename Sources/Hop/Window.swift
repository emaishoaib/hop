import AppKit

/// A window on the current Space, as the switcher lists it.
struct Window {
    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String

    /// The windows a switch lists: the normal app windows on screen, frontmost first, then the ones that are off screen
    /// because they're minimized or their app is hidden.
    ///
    /// Windows on screen under 100 points in either direction are skipped, since those are apps' helper windows,
    /// not windows you'd switch to. So are prompts, such as one asking whether to save changes, once the app
    /// has reported them through Accessibility. For `.activeApp`, only the frontmost app's windows are kept.
    /// No app is asked anything here. What they report is kept ahead of time by `KnownWindows`.
    @MainActor
    static func listed(_ scope: Hotkeys.Scope) -> [Window] {
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && (scope == .allApps || $0.processIdentifier == frontmostPID) }
        let standalone = onScreen(scope).filter { window in
            KnownWindows.of(window.pid)?.contains { $0.id == window.id && $0.isModal } != true
        }
        return standalone + offScreen(apps, besides: Set(standalone.map(\.id)))
    }

    /// The minimized windows of `apps`, and every window of a hidden app. These are off screen until they're switched to.
    ///
    /// They're taken from what the apps last reported through Accessibility, because the window list also reports apps'
    /// off-screen helper windows and gives no way to tell them apart. A window that has closed since, or that's
    /// among `onScreen` because it came back before its app reported it, is left out.
    @MainActor
    private static func offScreen(_ apps: [NSRunningApplication], besides onScreen: Set<CGWindowID>) -> [Window] {
        let entries = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[CFString: Any]] ?? []
        let open = Set(entries.compactMap { $0[kCGWindowNumber] as? CGWindowID })
        return apps.flatMap { app in
            (KnownWindows.of(app.processIdentifier) ?? [])
                .filter { (app.isHidden || $0.isMinimized) && open.contains($0.id) && !onScreen.contains($0.id) }
                .map { Window(id: $0.id, pid: app.processIdentifier, appName: app.localizedName ?? "", title: $0.title) }
        }
    }

    @MainActor
    private static func onScreen(_ scope: Hotkeys.Scope) -> [Window] {
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
    /// For a VS Code window on something that isn't a file, such as a diff, it's the name of the folder open in VS Code.
    /// Otherwise it's the window's title, or the app's name when the window has no title.
    var label: String {
        vsCodeRepoName ?? vsCodeFolderName ?? (title.isEmpty ? appName : title)
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

    /// The name of the folder open in this window, read from its title, when this is a VS Code window.
    ///
    /// VS Code titles its windows `<tab> — <folder>`, so the folder is the piece after the first ` — `.
    private var vsCodeFolderName: String? {
        guard NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.microsoft.VSCode" else { return nil }
        let pieces = title.components(separatedBy: " — ")
        return pieces.count > 1 ? pieces[1] : nil
    }

    /// Brings this window to the front and makes its app the active one, leaving the app's other windows where they are.
    ///
    /// The window is made its app's main window and raised first, because activating the app brings only its front window forward.
    /// That activation uses a deprecated Carbon function, because `NSRunningApplication.activate` can bring all of an app's
    /// windows forward whatever its options say. `activate` is only the fallback for when the Carbon function fails.
    /// When the window can't be found through Accessibility, the app is still activated.
    /// A hidden app is shown again first, which brings back all of its windows, and a minimized window is taken out of the Dock.
    func focus() {
        let app = NSRunningApplication(processIdentifier: pid)
        app?.unhide()
        if let window = accessibilityWindow(in: AXUIElementCreateApplication(pid)) {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }
        var process = ProcessSerialNumber()
        guard GetProcessForPID(pid, &process) == noErr,
              SetFrontProcessWithOptions(&process, OptionBits(kSetFrontProcessFrontWindowOnly)) == noErr
        else {
            app?.activate(options: [])
            return
        }
    }

    /// Asks this window to close, the same as clicking its close button, so the app can still ask to save first.
    func close() {
        var button: CFTypeRef?
        guard let window = accessibilityWindow(in: AXUIElementCreateApplication(pid)),
              AXUIElementCopyAttributeValue(window, kAXCloseButtonAttribute as CFString, &button) == .success,
              let button, CFGetTypeID(button) == AXUIElementGetTypeID()
        else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    /// Whether this window is gone: its app has quit, or no longer reports it through Accessibility.
    ///
    /// An app that doesn't answer within a quarter of a second counts as still having the window.
    var isClosed: Bool {
        guard let app = NSRunningApplication(processIdentifier: pid), !app.isTerminated else { return true }
        var value: CFTypeRef?
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, 0.25)
        guard AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement]
        else { return false }
        return !windows.contains { window in
            var windowID: CGWindowID = 0
            return _AXUIElementGetWindow(window, &windowID) == .success && windowID == id
        }
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

/// Finds the Carbon process number of the app `pid`, which `SetFrontProcessWithOptions` takes.
///
/// This is declared here because Swift hides functions deprecated as of macOS 10.9.
@_silgen_name("GetProcessForPID")
func GetProcessForPID(_ pid: pid_t, _ process: UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus

/// Makes `process` the active app, with `options` saying which of its windows come forward.
///
/// This is declared here because Swift hides functions deprecated as of macOS 10.9.
@_silgen_name("SetFrontProcessWithOptions")
func SetFrontProcessWithOptions(_ process: UnsafePointer<ProcessSerialNumber>, _ options: OptionBits) -> OSStatus
