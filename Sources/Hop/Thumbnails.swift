import ScreenCaptureKit

/// Captures window thumbnails with ScreenCaptureKit, which needs Screen Recording permission.
///
/// The last capture of each window is kept, so a switch can show it straight away while a fresh one is taken.
@MainActor
enum Thumbnails {
    private static var cache: [CGWindowID: NSImage] = [:]

    /// Shows each tile's last thumbnail right away, then captures every window at once
    /// and fades each fresh thumbnail in as soon as it arrives.
    ///
    /// A window that is off screen, such as a hidden app's, keeps the thumbnail taken while it was on screen.
    /// It's only captured when there is no such thumbnail. Thumbnails are dropped once their window is closed.
    static func load(into tiles: [Tile]) {
        for tile in tiles {
            if let image = cache[tile.windowID] { tile.thumbnail.image = image }
        }
        Task {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) else { return }
            cache = cache.filter { id, _ in content.windows.contains { $0.windowID == id } }
            for tile in tiles {
                guard let window = content.windows.first(where: { $0.windowID == tile.windowID }),
                      window.isOnScreen || cache[tile.windowID] == nil
                else { continue }
                Task {
                    guard let image = await capture(window, width: tile.thumbnailWidth) else { return }
                    cache[tile.windowID] = image
                    tile.fadeIn(image)
                }
            }
        }
    }

    /// A capture of `window`, sized for a thumbnail `width` points wide on a Retina screen.
    private static func capture(_ window: SCWindow, width: CGFloat) async -> NSImage? {
        let scale = min(1, 2 * width / window.frame.width)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return nil }
        return NSImage(cgImage: image, size: .zero)
    }
}
