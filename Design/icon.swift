// Generates the Focal app icon (AppIcon.icns) and a README banner. Run: swift icon.swift
import AppKit
import CoreImage

let out = FileManager.default.currentDirectoryPath

/// Blurred soft shape: a rounded rect rendered through CIGaussianBlur.
func blurredRect(_ rect: CGRect, color: NSColor, radius: CGFloat, canvas: CGSize) -> CIImage {
    let img = NSImage(size: canvas, flipped: false) { _ in
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height * 0.12, yRadius: rect.height * 0.12).fill()
        return true
    }
    let ci = CIImage(data: img.tiffRepresentation!)!
    return ci.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: CGRect(origin: .zero, size: canvas))
}

/// The mark: dark squircle, two blurred "windows" behind, one crisp lens in front.
func drawMark(size s: CGFloat, margin: CGFloat) -> NSImage {
    let canvas = CGSize(width: s, height: s)
    return NSImage(size: canvas, flipped: false) { _ in
        let inset = s * margin
        let box = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
        let squircle = NSBezierPath(roundedRect: box, xRadius: box.width * 0.2237, yRadius: box.width * 0.2237)

        // Background
        squircle.addClip()
        NSGradient(colors: [NSColor(red: 0.16, green: 0.18, blue: 0.26, alpha: 1),
                            NSColor(red: 0.05, green: 0.05, blue: 0.09, alpha: 1)])!
            .draw(in: box, angle: -90)

        // Blurred windows behind (the clutter)
        let ctx = NSGraphicsContext.current!.cgContext
        let ci = CIContext()
        let b = box.width
        let shapes: [(CGRect, NSColor)] = [
            (CGRect(x: box.minX + b * 0.10, y: box.minY + b * 0.50, width: b * 0.46, height: b * 0.30), NSColor(red: 1.0, green: 0.62, blue: 0.30, alpha: 0.85)),
            (CGRect(x: box.minX + b * 0.50, y: box.minY + b * 0.22, width: b * 0.42, height: b * 0.30), NSColor(red: 0.30, green: 0.80, blue: 0.85, alpha: 0.85)),
        ]
        for (r, c) in shapes {
            let img = blurredRect(r, color: c, radius: b * 0.045, canvas: canvas)
            if let cg = ci.createCGImage(img, from: img.extent) {
                ctx.draw(cg, in: CGRect(origin: .zero, size: canvas))
            }
        }

        // Crisp lens in front: ring + left half filled (matches the ◐ menu bar icon)
        let d = b * 0.44
        let lens = CGRect(x: box.midX - d / 2, y: box.midY - d / 2, width: d, height: d)
        let shadow = NSShadow()
        shadow.shadowBlurRadius = b * 0.05
        shadow.shadowOffset = NSSize(width: 0, height: -b * 0.02)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
        shadow.set()
        let ring = NSBezierPath(ovalIn: lens)
        ring.lineWidth = b * 0.05
        NSColor.white.setStroke()
        ring.stroke()
        NSShadow().set()
        NSColor.white.setFill()
        let half = NSBezierPath()
        half.appendArc(withCenter: CGPoint(x: lens.midX, y: lens.midY), radius: d / 2, startAngle: 90, endAngle: 270)
        half.close()
        half.fill()
        return true
    }
}

func png(_ image: NSImage, size: Int, path: String) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: CGRect(x: 0, y: 0, width: size, height: size), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

// Iconset: Apple's macOS icon grid keeps ~10% transparent margin around the squircle.
let iconset = "\(out)/AppIcon.iconset"
try? FileManager.default.removeItem(atPath: iconset)
try! FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
let mark = drawMark(size: 1024, margin: 0.1)
for base in [16, 32, 128, 256, 512] {
    png(mark, size: base, path: "\(iconset)/icon_\(base)x\(base).png")
    png(mark, size: base * 2, path: "\(iconset)/icon_\(base)x\(base)@2x.png")
}
png(mark, size: 1024, path: "\(out)/icon-1024.png")

// README banner 1280x640: mark + wordmark + tagline
let banner = NSImage(size: CGSize(width: 1280, height: 640), flipped: false) { _ in
    NSGradient(colors: [NSColor(red: 0.09, green: 0.10, blue: 0.14, alpha: 1),
                        NSColor(red: 0.04, green: 0.04, blue: 0.06, alpha: 1)])!
        .draw(in: CGRect(x: 0, y: 0, width: 1280, height: 640), angle: -90)
    drawMark(size: 300, margin: 0.0).draw(in: CGRect(x: 250, y: 170, width: 300, height: 300))
    let title = NSAttributedString(string: "Focal", attributes: [
        .font: NSFont.systemFont(ofSize: 112, weight: .bold), .foregroundColor: NSColor.white, .kern: -3])
    title.draw(at: CGPoint(x: 610, y: 330))
    let tag = NSAttributedString(string: "Blur everything except\nthe window you're working in.", attributes: [
        .font: NSFont.systemFont(ofSize: 34, weight: .regular),
        .foregroundColor: NSColor(white: 1, alpha: 0.7)])
    tag.draw(at: CGPoint(x: 616, y: 220))
    let sub = NSAttributedString(string: "Free, open source, for macOS", attributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .medium),
        .foregroundColor: NSColor(white: 1, alpha: 0.4)])
    sub.draw(at: CGPoint(x: 618, y: 170))
    return true
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2560, pixelsHigh: 1280, bitsPerSample: 8, samplesPerPixel: 4,
                           hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
banner.draw(in: CGRect(x: 0, y: 0, width: 2560, height: 1280), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/banner.png"))
print("done")
