import AppKit

struct ReportedWindow {
    let id: CGWindowID
    let isModal: Bool
    let isMinimized: Bool
    let title: String

    static func windows(of pid: pid_t) -> [ReportedWindow]? {
        guard let windows = AXUIElement.appWithShortTimeout(pid).windows, !windows.isEmpty else { return nil }
        let attributes = [kAXModalAttribute, kAXMinimizedAttribute, kAXTitleAttribute]
        return windows.compactMap { window in
            guard let id = window.windowID else { return nil }
            var values: CFArray?
            AXUIElementCopyMultipleAttributeValues(window, attributes as CFArray, [], &values)
            let answers = values as? [Any] ?? []
            guard answers.count == attributes.count else { return ReportedWindow(id: id, isModal: false, isMinimized: false, title: "") }
            return ReportedWindow(id: id, isModal: answers[0] as? Bool == true, isMinimized: answers[1] as? Bool == true, title: answers[2] as? String ?? "")
        }
    }
}
