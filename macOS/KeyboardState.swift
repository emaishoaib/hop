import Carbon.HIToolbox
import CoreGraphics

enum KeyboardState {
    case closed(lastNumber: Int)
    case open(number: Int)

    mutating func action(for type: CGEventType, keyCode: Int, optionHeld: Bool) -> SwitchAction? {
        switch (type, self) {
        case (.keyDown, .open(let number)) where optionHeld:
            if keyCode == kVK_Escape {
                self = .closed(lastNumber: number)
                return .cancel
            }
            if let direction = SwitchDirection(keyCode: keyCode) { return .move(direction) }
            return SwitchScope(keyCode: keyCode) == nil ? nil : .next
        case (.keyDown, .closed(let lastNumber)) where optionHeld:
            guard let scope = SwitchScope(keyCode: keyCode) else { return nil }
            self = .open(number: lastNumber + 1)
            return .open(scope, number: lastNumber + 1)
        case (.flagsChanged, .open(let number)) where !optionHeld:
            self = .closed(lastNumber: number)
            return .release
        default:
            return nil
        }
    }

    mutating func end(_ number: Int) {
        if case .open(number) = self { self = .closed(lastNumber: number) }
    }
}
