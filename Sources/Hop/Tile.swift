import AppKit

/// One window in the panel: a thumbnail with the app's icon and the window's title underneath.
///
/// The thumbnail starts as the app's icon and is replaced once the capture arrives.
/// Clicking the tile calls `onClick`, even though the panel's app is never the active one.
final class Tile: NSView {
    let windowID: CGWindowID
    let thumbnailWidth: CGFloat
    let thumbnail = NSImageView()
    var onClick: (@MainActor () -> Void)?

    var isSelected = false {
        didSet {
            layer?.backgroundColor = isSelected ? NSColor.systemBlue.withAlphaComponent(0.35).cgColor : nil
            layer?.borderColor = isSelected ? NSColor.systemBlue.cgColor : nil
            layer?.borderWidth = isSelected ? 2 : 0
        }
    }

    init(_ window: Window, width: CGFloat) {
        windowID = window.id
        thumbnailWidth = width
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10

        let appIcon = NSRunningApplication(processIdentifier: window.pid)?.icon
        thumbnail.image = appIcon
        thumbnail.imageScaling = .scaleProportionallyUpOrDown

        let icon = NSImageView()
        icon.image = appIcon
        icon.imageScaling = .scaleProportionallyUpOrDown
        let title = NSTextField(labelWithString: window.label)
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let label = NSStackView(views: [icon, title])
        label.spacing = 4

        let column = NSStackView(views: [thumbnail, label])
        column.orientation = .vertical
        column.spacing = 6
        column.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        column.translatesAutoresizingMaskIntoConstraints = false
        addSubview(column)

        NSLayoutConstraint.activate([
            column.leadingAnchor.constraint(equalTo: leadingAnchor),
            column.trailingAnchor.constraint(equalTo: trailingAnchor),
            column.topAnchor.constraint(equalTo: topAnchor),
            column.bottomAnchor.constraint(equalTo: bottomAnchor),
            thumbnail.widthAnchor.constraint(equalToConstant: width),
            thumbnail.heightAnchor.constraint(equalToConstant: width * 0.625),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: width),
        ])
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
