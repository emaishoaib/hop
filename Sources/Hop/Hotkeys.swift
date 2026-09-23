import AppKit
import Carbon.HIToolbox

/// Watches the keyboard system-wide for ⌥Tab and ⌥`, and for ⌥ being released.
///
/// The first press opens a switch, each further press while ⌥ is held advances it,
/// the arrow keys move the selection while it's open, Esc abandons it, and releasing ⌥ ends it.
/// These presses are swallowed so the focused app never sees them.
@MainActor
enum Hotkeys {
    enum Scope { case allApps, activeApp }

    private static var tap: CFMachPort?

    /// Starts listening to the keyboard. Needs Accessibility permission.
    static func start() {
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
            guard event.flags.contains(.maskAlternate) else { return false }
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            if Switcher.isOpen, keyCode == kVK_Escape {
                Switcher.cancel()
                return true
            }
            if Switcher.isOpen, let direction = direction(for: keyCode) {
                Switcher.move(direction)
                return true
            }
            guard let scope = scope(for: keyCode) else { return false }
            if Switcher.isOpen {
                Switcher.next()
            } else {
                Switcher.open(scope)
            }
            return true
        case .flagsChanged:
            if Switcher.isOpen, !event.flags.contains(.maskAlternate) {
                Switcher.release()
            }
        default:
            break
        }
        return false
    }

    /// The scope a key opens, or nil when it isn't Tab or `.
    private static func scope(for keyCode: Int) -> Scope? {
        switch keyCode {
        case kVK_Tab: .allApps
        case kVK_ANSI_Grave: .activeApp
        default: nil
        }
    }

    /// The direction an arrow key moves the selection, or nil when it isn't an arrow key.
    private static func direction(for keyCode: Int) -> Switcher.Direction? {
        switch keyCode {
        case kVK_LeftArrow: .left
        case kVK_RightArrow: .right
        case kVK_UpArrow: .up
        case kVK_DownArrow: .down
        default: nil
        }
    }
}
