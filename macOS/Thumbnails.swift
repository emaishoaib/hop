import ScreenCaptureKit

@MainActor
final class Thumbnails {
    static let shared = Thumbnails()

    private static let retinaScale: CGFloat = 2

    private var cache: [CGWindowID: NSImage] = [:]

    func load(into tiles: [Tile]) {
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

    private func capture(_ window: SCWindow, width: CGFloat) async -> NSImage? {
        let scale = min(1, Self.retinaScale * width / window.frame.width)
        let config = SCStreamConfiguration()
        config.width = Int(window.frame.width * scale)
        config.height = Int(window.frame.height * scale)
        config.showsCursor = false
        let filter = SCContentFilter(desktopIndependentWindow: window)
        guard let image = try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config) else { return nil }
        return NSImage(cgImage: image, size: .zero)
    }
}
