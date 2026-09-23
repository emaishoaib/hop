import ScreenCaptureKit

/// Captures window thumbnails with ScreenCaptureKit, which needs Screen Recording permission.
@MainActor
enum Thumbnails {
    /// Replaces each tile's placeholder with a capture of its window, one tile at a time as they arrive.
    static func load(into tiles: [Tile]) {
        Task {
            guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else { return }
            for tile in tiles {
                guard let window = content.windows.first(where: { $0.windowID == tile.windowID }) else { continue }
                let scale = min(1, 2 * tile.thumbnailWidth / window.frame.width)
                let config = SCStreamConfiguration()
                config.width = Int(window.frame.width * scale)
                config.height = Int(window.frame.height * scale)
                config.showsCursor = false
                let filter = SCContentFilter(desktopIndependentWindow: window)
                if let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) {
                    tile.thumbnail.image = NSImage(cgImage: image, size: .zero)
                }
            }
        }
    }
}
