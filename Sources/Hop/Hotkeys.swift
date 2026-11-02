import AppKit
import os

final class Hotkeys: @unchecked Sendable {
    static let shared = Hotkeys()

    private var tap: CFMachPort?
    private let state = OSAllocatedUnfairLock(initialState: KeyboardState.closed(lastNumber: 0))

    func start() {
        let thread = Thread { [self] in
            let mask = CGEventMask(1 << CGEventType.keyDown.rawValue | 1 << CGEventType.flagsChanged.rawValue)
            tap = CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: .headInsertEventTap,
                options: .defaultTap,
                eventsOfInterest: mask,
                callback: { _, type, event, _ in
                    Hotkeys.shared.handle(type, event) ? nil : Unmanaged.passUnretained(event)
                },
                userInfo: nil
            )
            guard let tap else { fatalError("Could not create the keyboard event tap") }
            CFRunLoopAddSource(CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
            CFRunLoopRun()
        }
        thread.name = "Hop keyboard"
        thread.qualityOfService = .userInteractive
        thread.start()
    }

    func switchEnded(_ number: Int) {
        state.withLock { $0.end(number) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return false
        }
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let optionHeld = event.flags.contains(.maskAlternate)
        guard let action = state.withLock({ $0.action(for: type, keyCode: keyCode, optionHeld: optionHeld) }) else { return false }
        DispatchQueue.main.async { Switcher.shared.perform(action) }
        return type == .keyDown
    }
}
