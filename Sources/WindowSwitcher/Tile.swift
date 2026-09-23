import AppKit

/// One window in the panel: a thumbnail with the window's title underneath.
///
/// The thumbnail starts as the app's icon and is replaced once the capture arrives.
/// Clicking the tile calls `onClick`, even though the panel's app is never the active one.
final class Tile: NSView {
    let windowID: CGWindowID
    let thumbnailWidth: CGFloat
    let thumbnail = NSImageView()
    var onClick: (@MainActor () -> Void)?

    var isSelected = false {
        didSet { layer?.backgroundColor = isSelected ? NSColor.white.withAlphaComponent(0.2).cgColor : nil }
    }

    init(_ window: Window, width: CGFloat) {
        windowID = window.id
        thumbnailWidth = width
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10

        thumbnail.image = NSRunningApplication(processIdentifier: window.pid)?.icon
        thumbnail.imageScaling = .scaleProportionallyUpOrDown

        let title = NSTextField(labelWithString: window.title.isEmpty ? window.appName : window.title)
        title.alignment = .center
        title.lineBreakMode = .byTruncatingTail

        let column = NSStackView(views: [thumbnail, title])
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
            title.widthAnchor.constraint(equalToConstant: width),
        ])
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        onClick?()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
