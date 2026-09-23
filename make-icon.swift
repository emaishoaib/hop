/// Draws the app icon and writes it to AppIcon.icns: a dark rounded square holding a 2 × 2 grid of
/// window tiles, with the top-right tile selected in blue, like the switcher panel.
///
/// Run it from this directory after changing the design: swift make-icon.swift
import AppKit

func color(_ hex: Int) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1)
}

func roundedRect(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, radius: CGFloat) -> NSBezierPath {
    NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: height), xRadius: radius, yRadius: radius)
}

/// The icon as a PNG `size` pixels square, drawn on a 1024-point canvas and scaled down.
func png(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let scale = NSAffineTransform()
    scale.scale(by: CGFloat(size) / 1024)
    scale.concat()

    color(0x1d2330).setFill()
    roundedRect(x: 100, y: 100, width: 824, height: 824, radius: 185).fill()

    color(0x566074).setFill()
    for (x, y) in [(223, 540), (223, 279), (539, 279)] as [(CGFloat, CGFloat)] {
        roundedRect(x: x, y: y, width: 261, height: 206, radius: 34).fill()
    }

    let selected = roundedRect(x: 539, y: 540, width: 261, height: 206, radius: 34)
    color(0x2f7cf6).setFill()
    selected.fill()
    color(0x9cc0ff).setStroke()
    selected.lineWidth = 21
    selected.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    try png(size: points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try png(size: points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", "AppIcon.icns"]
try iconutil.run()
iconutil.waitUntilExit()
