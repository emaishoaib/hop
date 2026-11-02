import AppKit

@MainActor
enum TileGrid {
    private static let spacing: CGFloat = 8
    private static let padding: CGFloat = 12
    private static let largestTileWidth: CGFloat = 280
    private static let smallestTileWidth: CGFloat = 60
    private static let shrinkFactor: CGFloat = 0.9

    static func measure(count: Int, sample: Window, in area: NSSize) -> (width: CGFloat, columns: Int) {
        var width = largestTileWidth
        while true {
            let tile = Tile(sample, width: width).fittingSize
            let columns = max(1, min(count, Int((area.width - 2 * padding + spacing) / (tile.width + spacing))))
            let rows = (count + columns - 1) / columns
            let height = CGFloat(rows) * (tile.height + spacing) - spacing + 2 * padding
            if height <= area.height || width <= smallestTileWidth { return (width, columns) }
            width *= shrinkFactor
        }
    }

    static func make(_ tiles: [Tile], columns: Int) -> NSStackView {
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
        return grid
    }
}
