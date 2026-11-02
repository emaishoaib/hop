import Carbon.HIToolbox

enum SwitchAction {
    case open(SwitchScope, number: Int)
    case next
    case move(SwitchDirection)
    case cancel
    case release
}

enum SwitchScope {
    case allApps, activeApp

    init?(keyCode: Int) {
        switch keyCode {
        case kVK_Tab: self = .allApps
        case kVK_ANSI_Grave: self = .activeApp
        default: return nil
        }
    }
}

enum SwitchDirection {
    case left, right, up, down

    init?(keyCode: Int) {
        switch keyCode {
        case kVK_LeftArrow: self = .left
        case kVK_RightArrow: self = .right
        case kVK_UpArrow: self = .up
        case kVK_DownArrow: self = .down
        default: return nil
        }
    }
}
