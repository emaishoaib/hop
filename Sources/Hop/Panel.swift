import AppKit

@MainActor
final class Panel {
    static let shared = Panel()

    private static let screenShare = 0.9
    private static let resizeDuration = 0.2
    private static let highlightDuration = 0.12
    private static let hideDuration = 0.1

    private struct Showing {
        let grid: NSView
        let tiles: [Tile]
        let columns: Int
    }

    private let window = PanelViews.makeWindow()
    private let highlight = PanelViews.makeHighlight()
    private var showing: Showing?

    var columns: Int { showing?.columns ?? 1 }

    func show(_ windows: [Window], selected: Int) {
        guard !windows.isEmpty, let screen = NSScreen.main, let content = window.contentView else { return }
        let previous = showing
        let previousTiles = previous?.tiles ?? []
        let framesBefore = Dictionary(uniqueKeysWithValues: previousTiles.compactMap { tile in
            PanelAnimation.frameOnScreen(of: tile).map { (tile.windowID, $0) }
        })
        let highlightBefore = previous == nil ? nil : PanelAnimation.frameOnScreen(of: highlight)
        let leaving = previousTiles.filter { tile in !windows.contains { $0.id == tile.windowID } }

        let area = screen.visibleFrame
        let limit = NSSize(width: area.width * Self.screenShare, height: area.height * Self.screenShare)
        let (width, columns) = TileGrid.measure(count: windows.count, sample: windows[0], in: limit)
        let tiles = windows.map { Tile($0, width: width) }
        for (index, tile) in tiles.enumerated() {
            tile.onClick = { Switcher.shared.pick(at: index) }
            tile.onClose = { Switcher.shared.closeWindow(at: index) }
            tile.onQuit = { Switcher.shared.quitApp(at: index) }
        }

        let grid = TileGrid.make(tiles, columns: columns)
        content.subviews.forEach { $0.removeFromSuperview() }
        content.addSubview(grid)
        grid.addSubview(highlight, positioned: .below, relativeTo: nil)
        showing = Showing(grid: grid, tiles: tiles, columns: columns)

        let size = grid.fittingSize
        let frame = NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
        content.layoutSubtreeIfNeeded()

        if previous != nil && !PanelAnimation.isReduced {
            PanelAnimation.slide(tiles, from: framesBefore)
            PanelAnimation.fadeOut(leaving, from: framesBefore, onto: grid, in: window)
            if let highlightBefore { highlight.frame = grid.convert(window.convertFromScreen(highlightBefore), from: nil) }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Self.resizeDuration
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
            highlight.isHidden = previous == nil
        }
        select(selected)
        if previous == nil { PanelAnimation.appear(window) }
        window.orderFrontRegardless()
        Thumbnails.shared.load(into: tiles)
    }

    func select(_ index: Int) {
        guard let showing, showing.tiles.indices.contains(index) else { return }
        let tile = showing.tiles[index]
        let target = tile.convert(tile.bounds, to: showing.grid)
        if highlight.isHidden || PanelAnimation.isReduced {
            highlight.frame = target
            highlight.isHidden = false
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Self.highlightDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = target
        }
    }

    func hide() {
        showing = nil
        guard !PanelAnimation.isReduced else { return window.orderOut(nil) }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Self.hideDuration
            window.animator().alphaValue = 0
        }, completionHandler: { [self] in
            MainActor.assumeIsolated {
                if showing == nil { window.orderOut(nil) }
            }
        })
    }
}
