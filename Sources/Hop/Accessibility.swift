import AppKit

@MainActor
enum Accessibility {
    private static let trustCheckInterval = Duration.seconds(1)

    static func whenTrusted(_ ready: @escaping @MainActor () -> Void) {
        if AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) { return ready() }
        NSApp.setActivationPolicy(.regular)
        Task {
            while !AXIsProcessTrusted() {
                try? await Task.sleep(for: trustCheckInterval)
            }
            NSApp.setActivationPolicy(.accessory)
            ready()
        }
    }
}
