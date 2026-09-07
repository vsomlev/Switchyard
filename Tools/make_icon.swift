import AppKit

// Renders the Switchyard app icon (a "junction": one node branching to three)
// at a given pixel size and returns PNG data.
func renderIcon(size: Int) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: s, height: s)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Transparent background (no frame) so it sits cleanly in the Finder toolbar.
    NSColor.clear.set()
    NSRect(x: 0, y: 0, width: s, height: s).fill()

    // Monochrome "junction" glyph: one node branching to three, in black with
    // thin strokes to match the other toolbar icons.
    let ink = NSColor.black
    let left = NSPoint(x: s * 0.30, y: s * 0.50)
    let rights = [
        NSPoint(x: s * 0.70, y: s * 0.72),
        NSPoint(x: s * 0.70, y: s * 0.50),
        NSPoint(x: s * 0.70, y: s * 0.28),
    ]

    // Connectors.
    let line = NSBezierPath()
    line.lineWidth = max(1, s * 0.028)
    line.lineCapStyle = .round
    line.lineJoinStyle = .round
    for r in rights {
        line.move(to: left)
        line.line(to: r)
    }
    ink.setStroke()
    line.stroke()

    // Nodes: filled dots with a thin outline for definition at small sizes.
    func dot(_ c: NSPoint, _ radius: CGFloat) {
        let r = NSRect(x: c.x - radius, y: c.y - radius, width: radius * 2, height: radius * 2)
        ink.setFill()
        NSBezierPath(ovalIn: r).fill()
    }
    dot(left, s * 0.052)
    for r in rights { dot(r, s * 0.042) }

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// iconset name -> pixel size
let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Switchyard.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
for (name, px) in sizes {
    let data = renderIcon(size: px)
    let url = URL(fileURLWithPath: "\(outDir)/\(name).png")
    try! data.write(to: url)
}
print("wrote iconset to \(outDir)")
