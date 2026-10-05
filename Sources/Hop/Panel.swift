import AppKit

/// The floating panel that shows one switch's windows in a grid and highlights the selected one.
///
/// It animates briefly unless Reduce Motion is on: it fades in and out, the highlight slides between tiles,
/// and when tiles are taken out, they fade away while the rest slide into their new places and the panel resizes.
@MainActor
enum Panel {
    private static let panel = makePanel()
    private static let highlight = makeHighlight()
    private static var grid: NSView?
    private static var tiles: [Tile] = []
    private(set) static var columns = 1
    private static let spacing: CGFloat = 8
    private static let padding: CGFloat = 12
    private static var isShowing = false

    /// Whether macOS's Reduce Motion setting is on, in which case nothing animates.
    static var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Shows a tile per window in rows that wrap, centred on the main screen, then starts loading their thumbnails.
    ///
    /// When the panel isn't showing yet, it fades in. When it is, the tiles that were already there
    /// slide to their new places and the panel resizes around them.
    static func show(_ windows: [Window], selected: Int) {
        guard !windows.isEmpty, let screen = NSScreen.main, let content = panel.contentView else { return }
        let wasShowing = isShowing
        let before = wasShowing ? Dictionary(uniqueKeysWithValues: tiles.compactMap { tile in screenFrame(of: tile).map { (tile.windowID, $0) } }) : [:]
        let highlightBefore = wasShowing ? screenFrame(of: highlight) : nil
        let leaving = tiles.filter { tile in !windows.contains { $0.id == tile.windowID } }

        let area = screen.visibleFrame
        let width: CGFloat
        (width, columns) = layout(count: windows.count, sample: windows[0], in: NSSize(width: area.width * 0.9, height: area.height * 0.9))
        tiles = windows.map { Tile($0, width: width) }
        for (index, tile) in tiles.enumerated() {
            tile.onClick = { Switcher.pick(index) }
            tile.onClose = { Switcher.closeWindow(index) }
            tile.onQuit = { Switcher.quitApp(index) }
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
        content.subviews.forEach { $0.removeFromSuperview() }
        content.addSubview(grid)
        grid.addSubview(highlight, positioned: .below, relativeTo: nil)
        self.grid = grid

        let size = grid.fittingSize
        let frame = NSRect(x: area.midX - size.width / 2, y: area.midY - size.height / 2, width: size.width, height: size.height)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            grid.centerYAnchor.constraint(equalTo: content.centerYAnchor),
        ])
        content.layoutSubtreeIfNeeded()

        if wasShowing && !reduceMotion {
            slide(from: before)
            fadeOut(leaving, from: before, onto: grid)
            if let highlightBefore { highlight.frame = grid.convert(panel.convertFromScreen(highlightBefore), from: nil) }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
            highlight.isHidden = !wasShowing
        }
        select(selected)
        if !wasShowing { appear() }
        isShowing = true
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

    /// Moves the highlight to the tile at `index`, sliding it there unless it was hidden.
    static func select(_ index: Int) {
        guard tiles.indices.contains(index), let grid else { return }
        let target = tiles[index].convert(tiles[index].bounds, to: grid)
        if highlight.isHidden || reduceMotion {
            highlight.frame = target
            highlight.isHidden = false
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            highlight.animator().frame = target
        }
    }

    /// Makes each tile that was already showing start from where it was, `before`, and slide to where it is now.
    private static func slide(from before: [CGWindowID: NSRect]) {
        for tile in tiles {
            guard let old = before[tile.windowID], let new = screenFrame(of: tile), let layer = tile.layer else { continue }
            let move = CABasicAnimation(keyPath: "transform")
            move.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(old.minX - new.minX, old.minY - new.minY, 0))
            move.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            move.duration = 0.2
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(move, forKey: "slide")
        }
    }

    /// Moves each tile in `leaving` onto `grid`, back where it was on screen according to `before`,
    /// and fades and shrinks it away while the other tiles slide into their new places.
    ///
    /// A leaving tile no longer responds to clicks, since its window is already out of the switch.
    private static func fadeOut(_ leaving: [Tile], from before: [CGWindowID: NSRect], onto grid: NSView) {
        for tile in leaving {
            guard let old = before[tile.windowID] else { continue }
            tile.onClick = nil
            tile.onClose = nil
            tile.onQuit = nil
            tile.removeFromSuperview()
            tile.translatesAutoresizingMaskIntoConstraints = true
            tile.frame = grid.convert(panel.convertFromScreen(old), from: nil)
            grid.addSubview(tile)

            let shrink = CABasicAnimation(keyPath: "transform")
            shrink.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            shrink.toValue = NSValue(caTransform3D: scaled(tile.bounds, by: 0.9))
            shrink.duration = 0.15
            shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
            shrink.fillMode = .forwards
            shrink.isRemovedOnCompletion = false
            tile.layer?.add(shrink, forKey: "shrink")
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.15
                tile.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated { tile.removeFromSuperview() }
            })
        }
    }

    /// Fades the panel in while it grows slightly from its centre.
    private static func appear() {
        panel.alphaValue = 1
        guard !reduceMotion, let content = panel.contentView, let layer = content.layer else { return }
        panel.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
        let grow = CABasicAnimation(keyPath: "transform")
        grow.fromValue = NSValue(caTransform3D: scaled(content.bounds, by: 0.96))
        grow.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        grow.duration = 0.15
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(grow, forKey: "grow")
    }

    /// A transform that scales something the size of `bounds` by `factor` around its centre,
    /// since AppKit's layers otherwise scale from their bottom-left corner.
    private static func scaled(_ bounds: CGRect, by factor: CGFloat) -> CATransform3D {
        let toCentre = CATransform3DMakeTranslation(bounds.midX, bounds.midY, 0)
        let scale = CATransform3DScale(toCentre, factor, factor, 1)
        return CATransform3DTranslate(scale, -bounds.midX, -bounds.midY, 0)
    }

    /// Where `view` is on screen, or nil when it isn't in a window.
    private static func screenFrame(of view: NSView) -> NSRect? {
        guard let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    /// Fades the panel out.
    ///
    /// Whatever the switch does next, such as focusing a window, happens straight away rather than after the fade.
    /// If the panel is shown again before the fade ends, it stays up.
    static func hide() {
        isShowing = false
        tiles = []
        guard !reduceMotion else { return panel.orderOut(nil) }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated {
                if !isShowing { panel.orderOut(nil) }
            }
        })
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

    /// The blue rounded box that sits behind the selected tile.
    private static func makeHighlight() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.35).cgColor
        view.layer?.borderColor = NSColor.systemBlue.cgColor
        view.layer?.borderWidth = 2
        return view
    }
}
