import AppKit
import Carbon.HIToolbox

/// Watches the keyboard system-wide for ⌥Tab and ⌥`, and for ⌥ being released.
///
/// The first press opens a switch, each further press while ⌥ is held advances it,
/// and releasing ⌥ ends it. The Tab and ` presses are swallowed so the focused app
/// never sees them.
@MainActor
enum Hotkeys {
    enum Scope { case allApps, activeApp }

    private static var tap: CFMachPort?
    private static var isOpen = false

    /// Starts listening once Accessibility permission is granted.
    ///
    /// Without it, the app prompts once, shows its Dock icon, and checks again every second.
    /// The Dock icon hides again as soon as the permission is granted.
    static func start() {
        if AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) { return listen() }
        NSApp.setActivationPolicy(.regular)
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            MainActor.assumeIsolated {
                NSApp.setActivationPolicy(.accessory)
                listen()
            }
        }
    }

    private static func listen() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.flagsChanged.rawValue)
        tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, _ in
                let swallow = MainActor.assumeIsolated { Hotkeys.handle(type, event) }
                return swallow ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: nil
        )
        guard let tap else { fatalError("Could not create the keyboard event tap") }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
    }

    /// Updates the switch state for one event and returns whether to swallow it.
    private static func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .keyDown:
            guard event.flags.contains(.maskAlternate), let scope = scope(for: event) else { return false }
            if isOpen {
                Switcher.next()
            } else {
                isOpen = true
                Switcher.open(scope)
            }
            return true
        case .flagsChanged:
            if isOpen, !event.flags.contains(.maskAlternate) {
                isOpen = false
                Switcher.release()
            }
        default:
            break
        }
        return false
    }

    /// The scope a key opens, or nil when it isn't one of the switcher's keys.
    private static func scope(for event: CGEvent) -> Scope? {
        switch Int(event.getIntegerValueField(.keyboardEventKeycode)) {
        case kVK_Tab: .allApps
        case kVK_ANSI_Grave: .activeApp
        default: nil
        }
    }
}
