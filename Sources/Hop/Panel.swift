import AppKit

/// The floating panel that shows one switch's windows in a grid and highlights the selected one.
@MainActor
enum Panel {
    private static let panel = makePanel()
    private static var tiles: [Tile] = []
    private(set) static var columns = 1
    private static let spacing: CGFloat = 8
    private static let padding: CGFloat = 12

    /// Shows a tile per window in rows that wrap, centred on the main screen, then starts loading their thumbnails.
    static func show(_ windows: [Window], selected: Int) {
        guard !windows.isEmpty, let screen = NSScreen.main else { return }
        let area = screen.visibleFrame
        let width: CGFloat
        (width, columns) = layout(count: windows.count, sample: windows[0], in: NSSize(width: area.width * 0.9, height: area.height * 0.9))
        tiles = windows.map { Tile($0, width: width) }
        for (index, tile) in tiles.enumerated() {
            tile.onHover = { Switcher.select(index) }
            tile.onClick = { Switcher.pick(index) }
        }

        let rows = stride(from: 0, to: tiles.count, by: columns).map { start in
            let row = NSStackView(views: Array(tiles[start..<min(start + columns, tiles.count)]))
            row.spacing = spacing
            return row
        }
        let grid = NSStackView(views: rows)
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = spacing
        grid.edgeInsets = NSEdgeInsets(top: padding, left: padding, bottom: padding, right: padding)
        panel.contentView?.subviews.forEach { $0.removeFromSuperview() }
        panel.contentView?.addSubview(grid)

        let size = grid.fittingSize
        grid.frame = NSRect(origin: .zero, size: size)
        panel.setFrame(NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height), display: true)
        select(selected)
        panel.orderFrontRegardless()
        Thumbnails.load(into: tiles)
    }

    /// The thumbnail width to use, up to 280 points, and how many tiles go in a row.
    ///
    /// Tiles only get smaller when the grid at full size would be taller than `area`.
    private static func layout(count: Int, sample: Window, in area: NSSize) -> (width: CGFloat, columns: Int) {
        var width: CGFloat = 280
        while true {
            let tile = Tile(sample, width: width).fittingSize
            let columns = max(1, min(count, Int((area.width - 2 * padding + spacing) / (tile.width + spacing))))
            let rows = (count + columns - 1) / columns
            let height = CGFloat(rows) * (tile.height + spacing) - spacing + 2 * padding
            if height <= area.height || width <= 60 { return (width, columns) }
            width *= 0.9
        }
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
        panel.ignoresMouseEvents = false
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
