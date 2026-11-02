import AppKit

@MainActor
enum PanelAnimation {
    private static let slideDuration = 0.2
    private static let fadeDuration = 0.15
    private static let leavingScale: CGFloat = 0.9
    private static let appearingScale: CGFloat = 0.96

    static var isReduced: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    static func frameOnScreen(of view: NSView) -> NSRect? {
        guard let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }

    static func slide(_ tiles: [Tile], from before: [CGWindowID: NSRect]) {
        for tile in tiles {
            guard let old = before[tile.windowID], let new = frameOnScreen(of: tile), let layer = tile.layer else { continue }
            let move = CABasicAnimation(keyPath: "transform")
            move.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(old.minX - new.minX, old.minY - new.minY, 0))
            move.toValue = NSValue(caTransform3D: CATransform3DIdentity)
            move.duration = slideDuration
            move.timingFunction = CAMediaTimingFunction(name: .easeOut)
            layer.add(move, forKey: "slide")
        }
    }

    static func fadeOut(_ leaving: [Tile], from before: [CGWindowID: NSRect], onto grid: NSView, in window: NSPanel) {
        for tile in leaving {
            guard let old = before[tile.windowID] else { continue }
            tile.onClick = nil
            tile.onClose = nil
            tile.onQuit = nil
            tile.removeFromSuperview()
            tile.translatesAutoresizingMaskIntoConstraints = true
            tile.frame = grid.convert(window.convertFromScreen(old), from: nil)
            grid.addSubview(tile)

            let shrink = CABasicAnimation(keyPath: "transform")
            shrink.fromValue = NSValue(caTransform3D: CATransform3DIdentity)
            shrink.toValue = NSValue(caTransform3D: scaled(tile.bounds, by: leavingScale))
            shrink.duration = fadeDuration
            shrink.timingFunction = CAMediaTimingFunction(name: .easeIn)
            shrink.fillMode = .forwards
            shrink.isRemovedOnCompletion = false
            tile.layer?.add(shrink, forKey: "shrink")
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = fadeDuration
                tile.animator().alphaValue = 0
            }, completionHandler: {
                MainActor.assumeIsolated { tile.removeFromSuperview() }
            })
        }
    }

    static func appear(_ window: NSPanel) {
        window.alphaValue = 1
        guard !isReduced, let content = window.contentView, let layer = content.layer else { return }
        window.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = fadeDuration
            window.animator().alphaValue = 1
        }
        let grow = CABasicAnimation(keyPath: "transform")
        grow.fromValue = NSValue(caTransform3D: scaled(content.bounds, by: appearingScale))
        grow.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        grow.duration = fadeDuration
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(grow, forKey: "grow")
    }

    private static func scaled(_ bounds: CGRect, by factor: CGFloat) -> CATransform3D {
        let toCentre = CATransform3DMakeTranslation(bounds.midX, bounds.midY, 0)
        let scale = CATransform3DScale(toCentre, factor, factor, 1)
        return CATransform3DTranslate(scale, -bounds.midX, -bounds.midY, 0)
    }
}
