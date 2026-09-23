import AppKit

/// Waits for Accessibility permission, which the shortcuts, focusing windows and following focus all need.
@MainActor
enum Accessibility {
    /// Runs `ready` once Accessibility permission is granted.
    ///
    /// Without it, the app prompts once, shows its Dock icon, and checks again every second.
    /// The Dock icon hides again as soon as the permission is granted.
    static func whenTrusted(_ ready: @escaping @MainActor () -> Void) {
        if AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) { return ready() }
        NSApp.setActivationPolicy(.regular)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            MainActor.assumeIsolated {
                NSApp.setActivationPolicy(.accessory)
                ready()
            }
        }
    }
}
