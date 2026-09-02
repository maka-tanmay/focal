// Renders Design/download-button.png (2x) for the README.
import AppKit
let size = NSSize(width: 520, height: 112)
let img = NSImage(size: size, flipped: false) { rect in
    let pill = NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), xRadius: 52, yRadius: 52)
    let shadow = NSShadow(); shadow.shadowBlurRadius = 6; shadow.shadowOffset = NSSize(width: 0, height: -2); shadow.shadowColor = NSColor.black.withAlphaComponent(0.25); shadow.set()
    NSGradient(colors: [NSColor(red: 0.13, green: 0.55, blue: 1, alpha: 1), NSColor(red: 0.04, green: 0.42, blue: 0.93, alpha: 1)])!.draw(in: pill, angle: -90)
    NSShadow().set()
    let apple = NSImage(systemSymbolName: "apple.logo", accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: 44, weight: .medium))!
    let tinted = NSImage(size: apple.size, flipped: false) { r in
        apple.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
    }
    tinted.draw(in: NSRect(x: 58, y: (size.height - apple.size.height) / 2 + 2, width: apple.size.width, height: apple.size.height))
    let text = NSAttributedString(string: "Download for Mac", attributes: [
        .font: NSFont.systemFont(ofSize: 38, weight: .semibold), .foregroundColor: NSColor.white, .kern: -0.5])
    text.draw(at: NSPoint(x: 128, y: (size.height - text.size().height) / 2))
    return true
}
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width) * 2, pixelsHigh: Int(size.height) * 2, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
img.draw(in: NSRect(x: 0, y: 0, width: size.width * 2, height: size.height * 2), from: .zero, operation: .copy, fraction: 1)
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "download-button.png"))
print("ok")
