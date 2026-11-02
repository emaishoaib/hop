import AppKit

final class CornerButton: NSButton {
    convenience init(_ symbol: String, _ description: String, target: AnyObject, action: Selector) {
        self.init(frame: .zero)
        let colours = NSImage.SymbolConfiguration(paletteColors: [.white, NSColor.black.withAlphaComponent(0.6)])
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: description)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 18, weight: .regular).applying(colours))
        isBordered = false
        toolTip = description
        self.target = target
        self.action = action
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
