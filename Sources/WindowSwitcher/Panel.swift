import AppKit

/// The floating panel that shows one switch's windows in a row and highlights the selected one.
@MainActor
enum Panel {
    private static let panel = makePanel()
    private static var tiles: [Tile] = []

    /// Shows a tile per window, centred on the main screen, then starts loading their thumbnails.
    static func show(_ windows: [Window], selected: Int) {
        guard !windows.isEmpty, let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        let width = min(220, area.width * 0.9 / CGFloat(windows.count) - 24)
        tiles = windows.map { Tile($0, width: width) }

        let row = NSStackView(views: tiles)
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        panel.contentView?.subviews.forEach { $0.removeFromSuperview() }
        panel.contentView?.addSubview(row)

        let size = row.fittingSize
        row.frame = NSRect(origin: .zero, size: size)
        panel.setFrame(NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height), display: true)
        select(selected)
        panel.orderFrontRegardless()
        Thumbnails.load(into: tiles)
    }

    /// Moves the highlight to the tile at `index`.
    static func select(_ index: Int) {
        for (i, tile) in tiles.enumerated() { tile.isSelected = i == index }
    }

    static func hide() {
        panel.orderOut(nil)
        tiles = []
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let background = NSVisualEffectView()
        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 16
        background.layer?.masksToBounds = true
        panel.contentView = background
        return panel
    }
}
