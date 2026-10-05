import AppKit
import Carbon.HIToolbox
import os

/// Watches the keyboard system-wide for ⌥Tab and ⌥`, and for ⌥ being released.
///
/// The first press opens a switch, each further press while ⌥ is held advances it,
/// the arrow keys move the selection while it's open, Esc abandons it, and releasing ⌥ ends it.
/// These presses are swallowed so the focused app never sees them.
@MainActor
enum Hotkeys {
    enum Scope { case allApps, activeApp }

    /// What a key press asks of the switch.
    ///
    /// Opening carries the number of the switch it opens, which `switchEnded` takes back.
    enum Action {
        case open(Scope, number: Int)
        case next
        case move(Switcher.Direction)
        case cancel
        case release
    }

    /// Whether a switch is open as far as key presses go, and how many have been opened so far.
    private struct Switches {
        var isOpen = false
        var count = 0
    }

    private static var tap: CFMachPort?
    private static let switches = OSAllocatedUnfairLock(initialState: Switches())

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
    ///
    /// Whether a switch is open is read from `switches` and updated there in the same step,
    /// so the answer never depends on how far the switcher has got with earlier key presses.
    private static func decide(_ type: CGEventType, _ event: CGEvent) -> Action? {
        let optionHeld = event.flags.contains(.maskAlternate)
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let direction = direction(for: keyCode)
        let scope = scope(for: keyCode)
        return switches.withLock { switches in
            switch type {
            case .keyDown where optionHeld:
                if switches.isOpen, keyCode == kVK_Escape {
                    switches.isOpen = false
                    return .cancel
                }
                if switches.isOpen, let direction { return .move(direction) }
                guard let scope else { return nil }
                if switches.isOpen { return .next }
                switches.isOpen = true
                switches.count += 1
                return .open(scope, number: switches.count)
            case .flagsChanged where switches.isOpen && !optionHeld:
                switches.isOpen = false
                return .release
            default:
                return nil
            }
        }
    }

    /// Tells the keyboard that switch `number` has ended, however it ended.
    ///
    /// The switcher calls this for every switch it closes, since a switch can also end on a click or by running out of windows.
    /// It's ignored when a newer switch has been opened since, so a late report can't mark that one as closed.
    static func switchEnded(_ number: Int) {
        switches.withLock { switches in
            if switches.count == number { switches.isOpen = false }
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
