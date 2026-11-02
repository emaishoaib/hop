import AppKit

extension Window {
    private static let smallestSide: CGFloat = 100

    @MainActor
    static func listed(_ scope: SwitchScope) -> [Window] {
        let frontmostPID = NSWorkspace.shared.frontmostPID
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && (scope == .allApps || $0.processIdentifier == frontmostPID) }
        let standalone = onScreen(scope).filter { window in
            KnownWindows.shared.windows(of: window.pid)?.contains { $0.id == window.id && $0.isModal } != true
        }
        return standalone + offScreen(apps, besides: Set(standalone.map(\.id)))
    }

    @MainActor
    private static func offScreen(_ apps: [NSRunningApplication], besides onScreen: Set<CGWindowID>) -> [Window] {
        let entries = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[CFString: Any]] ?? []
        let open = Set(entries.compactMap { $0[kCGWindowNumber] as? CGWindowID })
        return apps.flatMap { app in
            (KnownWindows.shared.windows(of: app.processIdentifier) ?? [])
                .filter { (app.isHidden || $0.isMinimized) && open.contains($0.id) && !onScreen.contains($0.id) }
                .map { Window(id: $0.id, pid: app.processIdentifier, appName: app.localizedName ?? "", title: $0.title) }
        }
    }

    @MainActor
    private static func onScreen(_ scope: SwitchScope) -> [Window] {
        let entries = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[CFString: Any]] ?? []
        let ownPID = getpid()
        let frontmostPID = NSWorkspace.shared.frontmostPID
        return entries.compactMap { entry in
            guard entry[kCGWindowLayer] as? Int == 0,
                  (entry[kCGWindowAlpha] as? Double ?? 0) > 0,
                  let bounds = (entry[kCGWindowBounds] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0 as CFDictionary) }),
                  bounds.width >= smallestSide, bounds.height >= smallestSide,
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
