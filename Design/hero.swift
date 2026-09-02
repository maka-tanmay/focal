// Renders the README hero animation frames: three windows, a cursor clicks between them, the rest blur.
// Run: swift hero.swift   → frames/hero-NNN.png, then ffmpeg assembles shots/hero.gif
import AppKit
import CoreImage

let W: CGFloat = 1000, H: CGFloat = 562, fps = 12.0, duration = 7.2
let ci = CIContext()

struct Win { let title: String; let tint: NSColor; let rect: CGRect; let kind: Int }
let wins = [
    Win(title: "Notes", tint: NSColor(red: 1, green: 0.8, blue: 0.2, alpha: 1), rect: CGRect(x: 90, y: 150, width: 380, height: 250), kind: 0),
    Win(title: "Safari", tint: NSColor(red: 0.2, green: 0.55, blue: 1, alpha: 1), rect: CGRect(x: 330, y: 90, width: 420, height: 280), kind: 1),
    Win(title: "Mail", tint: NSColor(red: 0.25, green: 0.8, blue: 0.9, alpha: 1), rect: CGRect(x: 600, y: 170, width: 340, height: 240), kind: 2),
]
// Timeline: (time cursor starts moving to window i, time of click)
let script: [(move: Double, click: Double, target: Int)] = [(0.0, 0.7, 0), (2.4, 3.1, 1), (4.8, 5.5, 2)]

func ease(_ t: CGFloat) -> CGFloat { t < 0 ? 0 : t > 1 ? 1 : t * t * (3 - 2 * t) }

func windowImage(_ w: Win) -> NSImage {
    NSImage(size: w.rect.size, flipped: false) { r in
        let path = NSBezierPath(roundedRect: r, xRadius: 12, yRadius: 12)
        path.addClip()
        NSColor(white: 0.13, alpha: 1).setFill(); r.fill()
        // title bar
        NSColor(white: 0.2, alpha: 1).setFill(); NSRect(x: 0, y: r.height - 34, width: r.width, height: 34).fill()
        for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
            c.setFill(); NSBezierPath(ovalIn: NSRect(x: 14 + CGFloat(i) * 18, y: r.height - 23, width: 12, height: 12)).fill()
        }
        let t = NSAttributedString(string: w.title, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NSColor(white: 0.75, alpha: 1)])
        t.draw(at: NSPoint(x: (r.width - t.size().width) / 2, y: r.height - 26))
        // body
        let body = NSRect(x: 20, y: 20, width: r.width - 40, height: r.height - 74)
        switch w.kind {
        case 0:
            w.tint.setFill(); NSBezierPath(roundedRect: NSRect(x: body.minX, y: body.maxY - 16, width: 150, height: 14), xRadius: 4, yRadius: 4).fill()
            for (i, f) in [0.92, 0.7, 0.85, 0.55, 0.78].enumerated() {
                NSColor(white: 0.35, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: body.minX, y: body.maxY - 44 - CGFloat(i) * 24, width: body.width * f, height: 9), xRadius: 4, yRadius: 4).fill()
            }
        case 1:
            NSColor(white: 0.25, alpha: 1).setFill(); NSBezierPath(roundedRect: NSRect(x: body.minX, y: body.maxY - 22, width: body.width, height: 20), xRadius: 10, yRadius: 10).fill()
            for i in 0..<2 {
                w.tint.withAlphaComponent(i == 0 ? 0.7 : 0.4).setFill()
                NSBezierPath(roundedRect: NSRect(x: body.minX + CGFloat(i) * (body.width / 2 + 6), y: body.maxY - 130, width: body.width / 2 - 6, height: 96), xRadius: 8, yRadius: 8).fill()
            }
            for (i, f) in [0.9, 0.6].enumerated() {
                NSColor(white: 0.35, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: body.minX, y: body.maxY - 152 - CGFloat(i) * 22, width: body.width * f, height: 9), xRadius: 4, yRadius: 4).fill()
            }
        default:
            for i in 0..<5 {
                let y = body.maxY - 18 - CGFloat(i) * 34
                (i == 0 ? w.tint : NSColor.clear).setFill(); NSBezierPath(ovalIn: NSRect(x: body.minX, y: y, width: 8, height: 8)).fill()
                NSColor(white: i == 0 ? 0.6 : 0.35, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: body.minX + 18, y: y - 1, width: 110, height: 9), xRadius: 4, yRadius: 4).fill()
                NSColor(white: 0.28, alpha: 1).setFill()
                NSBezierPath(roundedRect: NSRect(x: body.minX + 140, y: y - 1, width: body.width - 140, height: 9), xRadius: 4, yRadius: 4).fill()
            }
        }
        NSColor(white: 1, alpha: 0.12).setStroke(); path.lineWidth = 1; path.stroke()
        return true
    }
}
let winImages = wins.map(windowImage)

func blurred(_ img: NSImage, radius: CGFloat) -> CGImage? {
    guard radius > 0.2 else { return img.cgImage(forProposedRect: nil, context: nil, hints: nil) }
    let input = CIImage(data: img.tiffRepresentation!)!
    let out = input.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: radius]).cropped(to: input.extent)
    return ci.createCGImage(out, from: out.extent)
}

func cursorPath(at p: CGPoint) -> NSBezierPath {
    let c = NSBezierPath()
    c.move(to: p); c.line(to: CGPoint(x: p.x, y: p.y - 22)); c.line(to: CGPoint(x: p.x + 5, y: p.y - 17))
    c.line(to: CGPoint(x: p.x + 9, y: p.y - 26)); c.line(to: CGPoint(x: p.x + 13, y: p.y - 24)); c.line(to: CGPoint(x: p.x + 9, y: p.y - 15))
    c.line(to: CGPoint(x: p.x + 16, y: p.y - 15)); c.close(); return c
}

func frame(at time: Double) -> NSImage {
    // state
    var active = -1, blurAmount: CGFloat = 0
    var cursor = CGPoint(x: 520, y: 40)
    var pressed = false
    for (i, s) in script.enumerated() {
        let target = CGPoint(x: wins[s.target].rect.midX + 40, y: wins[s.target].rect.midY - 10)
        let from = i == 0 ? CGPoint(x: 520, y: 40) : CGPoint(x: wins[script[i - 1].target].rect.midX + 40, y: wins[script[i - 1].target].rect.midY - 10)
        if time >= s.move { cursor = CGPoint(x: from.x + (target.x - from.x) * ease(CGFloat((time - s.move) / 0.6)), y: from.y + (target.y - from.y) * ease(CGFloat((time - s.move) / 0.6))) }
        if time >= s.click { active = s.target; blurAmount = ease(CGFloat((time - s.click) / 0.45)); pressed = time - s.click < 0.15 }
    }
    return NSImage(size: NSSize(width: W, height: H), flipped: false) { r in
        NSGradient(colors: [NSColor(red: 0.22, green: 0.26, blue: 0.45, alpha: 1), NSColor(red: 0.07, green: 0.08, blue: 0.16, alpha: 1)])!.draw(in: r, angle: -60)
        // menu bar
        NSColor(white: 1, alpha: 0.12).setFill(); NSRect(x: 0, y: H - 28, width: W, height: 28).fill()
        let glyph = NSBezierPath(ovalIn: NSRect(x: W - 150, y: H - 21, width: 14, height: 14)); glyph.lineWidth = 1.6; NSColor.white.setStroke(); glyph.stroke()
        let half = NSBezierPath(); half.appendArc(withCenter: NSPoint(x: W - 143, y: H - 14), radius: 7, startAngle: 90, endAngle: 270); half.close(); NSColor.white.setFill(); half.fill()
        for (i, s) in ["9:41", "◔", "▮"].enumerated() {
            NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white]).draw(at: NSPoint(x: W - 60 - CGFloat(i) * 34, y: H - 21))
        }
        // windows: draw blurred ones first (in original order), active on top
        let order = (0..<wins.count).sorted { a, b in (a == active ? 1 : 0) < (b == active ? 1 : 0) }
        for i in order {
            let w = wins[i]
            let isActive = i == active
            let radius: CGFloat = isActive ? 0 : 16 * blurAmount
            if isActive {
                let sh = NSShadow(); sh.shadowBlurRadius = 30; sh.shadowOffset = NSSize(width: 0, height: -14); sh.shadowColor = NSColor.black.withAlphaComponent(0.55); sh.set()
                NSColor.black.setFill(); NSBezierPath(roundedRect: w.rect, xRadius: 12, yRadius: 12).fill(); NSShadow().set()
            }
            if let cg = blurred(winImages[i], radius: radius) {
                NSGraphicsContext.current!.cgContext.draw(cg, in: w.rect)
            }
            if !isActive && blurAmount > 0 {
                NSColor.black.withAlphaComponent(0.28 * blurAmount).setFill()
                NSBezierPath(roundedRect: w.rect, xRadius: 12, yRadius: 12).fill()
            }
        }
        // caption
        let capAlpha = max(0, min(1, (time - 1.1) / 0.5))
        if capAlpha > 0 {
            let text = NSAttributedString(string: "Click a window. Everything else softens.", attributes: [
                .font: NSFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: NSColor.white.withAlphaComponent(capAlpha)])
            let sz = text.size()
            NSColor.black.withAlphaComponent(0.35 * capAlpha).setFill()
            NSBezierPath(roundedRect: NSRect(x: (W - sz.width) / 2 - 18, y: 26, width: sz.width + 36, height: sz.height + 16), xRadius: 22, yRadius: 22).fill()
            text.draw(at: NSPoint(x: (W - sz.width) / 2, y: 34))
        }
        // cursor
        let c = cursorPath(at: cursor)
        if pressed { c.transform(using: AffineTransform(translationByX: 1, byY: -1)) }
        NSColor.black.setStroke(); c.lineWidth = 2.5; c.lineJoinStyle = .round; c.stroke()
        NSColor.white.setFill(); c.fill()
        return true
    }
}

let total = Int(duration * fps)
for n in 0..<total {
    let img = frame(at: Double(n) / fps)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    img.draw(in: NSRect(x: 0, y: 0, width: W, height: H), from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: String(format: "frames/hero-%03d.png", n)))
}
print("frames", total)
