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

    /// What a key press asks of the switch.
    enum Action {
        case open(Scope)
        case next
        case move(Switcher.Direction)
        case cancel
        case release
    }

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

    /// Handles one event from the tap and returns whether to swallow it.
    ///
    /// A key press that the switch acts on is swallowed. ⌥ being released never is.
    /// When macOS has switched the tap off, it's switched back on.
    private static func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        guard let action = decide(type, event) else { return false }
        Switcher.perform(action)
        return type == .keyDown
    }

    /// What one event asks of the switch, or nil when the event isn't one of Hop's.
    private static func decide(_ type: CGEventType, _ event: CGEvent) -> Action? {
        let optionHeld = event.flags.contains(.maskAlternate)
        switch type {
        case .keyDown where optionHeld:
            let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
            if Switcher.isOpen, keyCode == kVK_Escape { return .cancel }
            if Switcher.isOpen, let direction = direction(for: keyCode) { return .move(direction) }
            guard let scope = scope(for: keyCode) else { return nil }
            return Switcher.isOpen ? .next : .open(scope)
        case .flagsChanged where Switcher.isOpen && !optionHeld:
            return .release
        default:
            return nil
        }
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
