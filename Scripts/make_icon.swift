// Draws the app icon and writes Icon.iconset. Run: swift Scripts/make_icon.swift && iconutil -c icns Icon.iconset
// The icon uses plain shapes only. Apple does not allow SF Symbols in an app icon.
import AppKit

func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    let unit = CGFloat(pixels) / 1024
    context.scaleBy(x: unit, y: unit)

    // The standard macOS icon plate: 824 points wide, with a continuous corner.
    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 185, cornerHeight: 185, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    context.addPath(platePath)
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(platePath)
    context.clip()
    let colors = [NSColor(white: 0.97, alpha: 1).cgColor, NSColor(red: 0.86, green: 0.87, blue: 0.91, alpha: 1).cgColor]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])

    // The pile: colored shapes on the ground. Each entry is x, y, size, rotation, color, shape.
    let pile: [(CGFloat, CGFloat, CGFloat, CGFloat, NSColor, Int)] = [
        (190, 175, 150, 0.2, .systemRed, 0), (330, 190, 170, -0.3, .systemOrange, 1), (480, 170, 140, 0.5, .systemYellow, 2),
        (610, 195, 175, 0.1, .systemGreen, 0), (770, 180, 160, -0.4, .systemBlue, 1), (870, 200, 120, 0.3, .systemPurple, 2),
        (260, 310, 140, 0.6, .systemTeal, 2), (410, 325, 150, -0.2, .systemPink, 0), (560, 330, 135, 0.4, .systemIndigo, 1),
        (710, 320, 150, -0.5, .systemMint, 2), (835, 330, 110, 0.2, .systemOrange, 0), (150, 300, 110, -0.2, .systemIndigo, 1),
    ]
    for (x, y, size, rotation, color, shape) in pile {
        context.saveGState()
        context.translateBy(x: x, y: y)
        context.rotate(by: rotation)
        context.setFillColor(color.cgColor)
        let box = CGRect(x: -size / 2, y: -size / 2, width: size, height: size)
        switch shape {
        case 0: context.fillEllipse(in: box)
        case 1: context.addPath(CGPath(roundedRect: box, cornerWidth: size * 0.26, cornerHeight: size * 0.26, transform: nil)); context.fillPath()
        default:
            context.move(to: CGPoint(x: 0, y: size * 0.55))
            context.addLine(to: CGPoint(x: size * 0.55, y: -size * 0.42))
            context.addLine(to: CGPoint(x: -size * 0.55, y: -size * 0.42))
            context.closePath()
            context.setLineJoin(.round)
            context.setLineWidth(size * 0.16)
            context.setStrokeColor(color.cgColor)
            context.drawPath(using: .fillStroke)
        }
        context.restoreGState()
    }

    // One shape floats up to the search bar.
    context.setFillColor(NSColor.systemBlue.cgColor)
    context.fillEllipse(in: CGRect(x: 452, y: 470, width: 120, height: 120))

    // The search bar.
    let bar = CGRect(x: 190, y: 650, width: 644, height: 150)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: NSColor.black.withAlphaComponent(0.18).cgColor)
    context.addPath(CGPath(roundedRect: bar, cornerWidth: 52, cornerHeight: 52, transform: nil))
    context.setFillColor(NSColor.white.cgColor)
    context.fillPath()
    context.restoreGState()
    // A magnifying glass from a circle and a line.
    context.setStrokeColor(NSColor(white: 0.35, alpha: 1).cgColor)
    context.setLineWidth(16)
    context.setLineCap(.round)
    context.strokeEllipse(in: CGRect(x: 240, y: 703, width: 56, height: 56))
    context.move(to: CGPoint(x: 290, y: 708))
    context.addLine(to: CGPoint(x: 312, y: 686))
    context.strokePath()
    // The typed text, as a rounded line.
    context.setFillColor(NSColor(white: 0.78, alpha: 1).cgColor)
    context.addPath(CGPath(roundedRect: CGRect(x: 350, y: 713, width: 300, height: 24), cornerWidth: 12, cornerHeight: 12, transform: nil))
    context.fillPath()
    context.restoreGState()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

let folder = URL(fileURLWithPath: "Icon.iconset")
try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
for (name, pixels) in [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64), ("icon_128x128", 128),
    ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512), ("icon_512x512", 512), ("icon_512x512@2x", 1024),
] {
    try render(pixels).write(to: folder.appendingPathComponent("\(name).png"))
}
