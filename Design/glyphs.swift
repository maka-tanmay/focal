// Renders menu bar glyph candidates (18pt at 4x) onto a contact sheet for review.
import AppKit
let S: CGFloat = 18, K: CGFloat = 4   // point size, scale
typealias Draw = (CGRect, Bool) -> Void   // (bounds, active)

let lw: CGFloat = 1.6
func circle(_ r: CGRect) -> NSBezierPath { NSBezierPath(ovalIn: r) }
func halfDisk(_ r: CGRect) -> NSBezierPath {
    let p = NSBezierPath(); p.appendArc(withCenter: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2, startAngle: 90, endAngle: 270); p.close(); return p
}
func dashedArc(_ r: CGRect, from a: CGFloat, to b: CGFloat) -> NSBezierPath {
    let p = NSBezierPath(); p.appendArc(withCenter: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2, startAngle: a, endAngle: b)
    p.lineWidth = lw; p.lineCapStyle = .round; p.setLineDash([0.1, 2.6], count: 2, phase: 0); return p
}

let candidates: [(String, Draw)] = [
    ("A  stock ◐", { b, on in
        let r = b.insetBy(dx: 2, dy: 2)
        let ring = circle(r.insetBy(dx: lw/2, dy: lw/2)); ring.lineWidth = lw; ring.stroke()
        if on { halfDisk(r).fill() }
    }),
    ("B  sharp | dotted", { b, on in
        let r = b.insetBy(dx: 2, dy: 2)
        if on {
            halfDisk(r).fill()
            dashedArc(r.insetBy(dx: lw/2, dy: lw/2), from: -90, to: 90).stroke()
        } else {
            dashedArc(r.insetBy(dx: lw/2, dy: lw/2), from: 0, to: 360).stroke()
        }
    }),
    ("C  lens + echo", { b, on in
        let r = b.insetBy(dx: 2.5, dy: 2.5)
        let front = r.offsetBy(dx: -1.2, dy: -1.2)
        let back = r.offsetBy(dx: 2.2, dy: 2.2).insetBy(dx: 1.5, dy: 1.5)
        let echo = circle(back.insetBy(dx: 0.5, dy: 0.5)); echo.lineWidth = 1; echo.stroke()
        // knock out the front area so the echo reads as behind
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        circle(front.insetBy(dx: -1, dy: -1)).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        let ring = circle(front.insetBy(dx: lw/2, dy: lw/2)); ring.lineWidth = lw; ring.stroke()
        if on { halfDisk(front).fill() }
    }),
    ("D  window + ghost", { b, on in
        let f = CGRect(x: b.minX + 1.5, y: b.minY + 1.5, width: 11, height: 9)
        let g = CGRect(x: b.minX + 6, y: b.minY + 6, width: 10.5, height: 8.5)
        let ghost = NSBezierPath(roundedRect: g.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
        ghost.lineWidth = 1; ghost.setLineDash([0.1, 2.2], count: 2, phase: 0); ghost.lineCapStyle = .round; ghost.stroke()
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSBezierPath(roundedRect: f.insetBy(dx: -1, dy: -1), xRadius: 3, yRadius: 3).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        let front = NSBezierPath(roundedRect: f, xRadius: 2.5, yRadius: 2.5)
        if on { front.fill() } else { front.lineWidth = lw; NSBezierPath(roundedRect: f.insetBy(dx: lw/2, dy: lw/2), xRadius: 2.5, yRadius: 2.5).stroke() }
    }),
]

// Contact sheet: each candidate at 4x on light and dark menu-bar strips, plus 1x actual size.
let cellW: CGFloat = 220, cellH: CGFloat = 120
let sheet = NSImage(size: CGSize(width: cellW * CGFloat(candidates.count), height: cellH * 2 + 40), flipped: false) { _ in
    for (i, (name, draw)) in candidates.enumerated() {
        let x = CGFloat(i) * cellW
        for (row, dark) in [false, true].enumerated() {
            let y = CGFloat(row) * cellH
            (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.93, alpha: 1)).setFill()
            CGRect(x: x, y: y, width: cellW, height: cellH).fill()
            (dark ? NSColor.white : NSColor.black).set()
            for (j, on) in [true, false].enumerated() {
                // 4x
                let ox = x + 20 + CGFloat(j) * 90
                let t = NSAffineTransform(); t.translateX(by: ox, yBy: y + 30); t.scale(by: K)
                NSGraphicsContext.saveGraphicsState(); t.concat()
                draw(CGRect(x: 0, y: 0, width: S, height: S), on)
                NSGraphicsContext.restoreGraphicsState()
                // 1x
                let t1 = NSAffineTransform(); t1.translateX(by: ox + 26, yBy: y + 8)
                NSGraphicsContext.saveGraphicsState(); t1.concat()
                draw(CGRect(x: 0, y: 0, width: S, height: S), on)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
        NSColor.black.set()
        NSAttributedString(string: name, attributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium)]).draw(at: CGPoint(x: x + 20, y: cellH * 2 + 10))
    }
    return true
}
let rep = NSBitmapImageRep(data: sheet.tiffRepresentation!)!
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "glyphs.png"))
print("ok")
