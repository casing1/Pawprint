import AppKit

/// Renders Pawprint's app icon at every size macOS wants and emits an .iconset directory.
/// Run via `scripts/make_icon.sh`, which then packs the result into Assets/AppIcon.icns.

let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1024, "icon_512x512@2x.png"),
]

guard CommandLine.arguments.count > 1 else {
    FileHandle.standardError.write("usage: make_icon <output.iconset dir>\n".data(using: .utf8)!)
    exit(1)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    guard let ctx = NSGraphicsContext.current?.cgContext else { return image }

    // macOS Big Sur+ icon geometry: rounded-rect "squircle" inset from the canvas edge.
    let inset = size * 0.055
    let rect = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let cornerRadius = rect.width * 0.2237

    let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()

    // Warm peach → coral gradient, matching the app's cozy/playful tone.
    let colors = [
        NSColor(calibratedRed: 1.00, green: 0.78, blue: 0.55, alpha: 1).cgColor,
        NSColor(calibratedRed: 0.98, green: 0.53, blue: 0.45, alpha: 1).cgColor,
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: rect.minX, y: rect.maxY),
            end: CGPoint(x: rect.maxX, y: rect.minY),
            options: []
        )
    }
    ctx.restoreGState()

    // Paw print: one main pad + four toes, drawn as plain ellipses so the shape stays crisp
    // even at 16px where an SF Symbol would turn to mush.
    let cx = rect.midX
    let cy = rect.midY
    let unit = rect.width

    NSColor.white.withAlphaComponent(0.95).setFill()

    let padW = unit * 0.40
    let padH = unit * 0.33
    let padRect = CGRect(x: cx - padW / 2, y: cy - padH * 0.78, width: padW, height: padH)
    ctx.addEllipse(in: padRect)
    ctx.fillPath()

    let toeW = unit * 0.155
    let toeH = unit * 0.205
    // (dx, dy, rotation) for each toe, arranged in an arc above the pad.
    let toes: [(CGFloat, CGFloat, CGFloat)] = [
        (-0.255, 0.105, 0.30),
        (-0.088, 0.225, 0.10),
        (0.088, 0.225, -0.10),
        (0.255, 0.105, -0.30),
    ]
    for (dx, dy, rot) in toes {
        ctx.saveGState()
        ctx.translateBy(x: cx + unit * dx, y: cy + unit * dy)
        ctx.rotate(by: rot)
        ctx.addEllipse(in: CGRect(x: -toeW / 2, y: -toeH / 2, width: toeW, height: toeH))
        ctx.fillPath()
        ctx.restoreGState()
    }

    return image
}

for (px, name) in sizes {
    let image = drawIcon(size: CGFloat(px))
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write("failed to render \(name)\n".data(using: .utf8)!)
        exit(1)
    }
    try png.write(to: outDir.appendingPathComponent(name))
}

print("wrote \(sizes.count) icon images to \(outDir.path)")
