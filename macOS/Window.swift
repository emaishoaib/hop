import AppKit

struct Window {
    private static let vsCodeBundleID = "com.microsoft.VSCode"
    private static let vsCodeTitleSeparator = " — "

    let id: CGWindowID
    let pid: pid_t
    let appName: String
    let title: String

    var label: String {
        vsCodeRepoName ?? vsCodeFolderName ?? (title.isEmpty ? appName : title)
    }

    var accessibilityWindow: AXUIElement? {
        AXUIElementCreateApplication(pid).windows?.first { $0.windowID == id }
    }

    private var isVSCode: Bool {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == Self.vsCodeBundleID
    }

    private var vsCodeRepoName: String? {
        var value: CFTypeRef?
        guard isVSCode,
              let accessibilityWindow,
              AXUIElementCopyAttributeValue(accessibilityWindow, kAXDocumentAttribute as CFString, &value) == .success,
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

    private var vsCodeFolderName: String? {
        guard isVSCode else { return nil }
        let pieces = title.components(separatedBy: Self.vsCodeTitleSeparator)
        return pieces.count > 1 ? pieces[1] : nil
    }
}
