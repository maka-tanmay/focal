import AppKit
import Carbon

/// User-visible customizations that aren't about the blur itself: menu bar icon and shortcut.
final class Prefs: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var iconStyle: IconStyle = IconStyle(rawValue: UserDefaults.standard.string(forKey: "iconStyle") ?? "") ?? .dotted {
        didSet { defaults.set(iconStyle.rawValue, forKey: "iconStyle") }
    }
    @Published var hotkey: Hotkey = (UserDefaults.standard.data(forKey: "hotkey")).flatMap { try? JSONDecoder().decode(Hotkey.self, from: $0) } ?? .standard {
        didSet { defaults.set(try? JSONEncoder().encode(hotkey), forKey: "hotkey") }
    }
}

struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32   // Carbon modifier mask
    var label: String       // e.g. "⌃⌥⌘F"

    static let standard = Hotkey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey | optionKey | controlKey), label: "⌃⌥⌘F")

    /// Builds a hotkey from a key event, or nil if it has no real modifier (⌘, ⌥ or ⌃).
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection([.command, .option, .control, .shift])
        guard !flags.isDisjoint(with: [.command, .option, .control]) else { return nil }
        var carbon: UInt32 = 0, symbols = ""
        if flags.contains(.control) { carbon |= UInt32(controlKey); symbols += "⌃" }
        if flags.contains(.option)  { carbon |= UInt32(optionKey);  symbols += "⌥" }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey);   symbols += "⇧" }
        if flags.contains(.command) { carbon |= UInt32(cmdKey);     symbols += "⌘" }
        keyCode = UInt32(event.keyCode)
        modifiers = carbon
        label = symbols + Hotkey.keyName(event)
    }

    init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.label = label
    }

    private static let special: [UInt16: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋", 123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6", 98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    private static func keyName(_ e: NSEvent) -> String {
        if let name = special[e.keyCode] { return name }
        let chars = e.charactersIgnoringModifiers ?? ""
        // ponytail: printable characters only; anything else falls back to the key code
        if let c = chars.unicodeScalars.first, c.value >= 0x20, c.value < 0xF700 { return chars.uppercased() }
        return "Key \(e.keyCode)"
    }
}

/// Menu bar glyph styles. Each is drawn as a template image so it follows the menu bar's light/dark look.
enum IconStyle: String, CaseIterable, Identifiable {
    case lens, dotted, window
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lens: return "Lens"
        case .dotted: return "Sharp and blurred"
        case .window: return "Window"
        }
    }

    func image(on: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            NSColor.black.set()
            let lw: CGFloat = 1.6
            switch self {
            case .lens:
                let r = bounds.insetBy(dx: 2, dy: 2)
                let ring = NSBezierPath(ovalIn: r.insetBy(dx: lw / 2, dy: lw / 2))
                ring.lineWidth = lw
                ring.stroke()
                if on { IconStyle.halfDisk(r).fill() }
            case .dotted:
                let r = bounds.insetBy(dx: 2, dy: 2)
                let dots = NSBezierPath()
                dots.appendArc(withCenter: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2 - 0.8,
                               startAngle: on ? -90 : 0, endAngle: on ? 90 : 360)
                dots.lineWidth = lw
                dots.lineCapStyle = .round
                dots.setLineDash([0.1, 2.6], count: 2, phase: 0)
                dots.stroke()
                if on { IconStyle.halfDisk(r).fill() }
            case .window:
                let front = CGRect(x: bounds.minX + 1.5, y: bounds.minY + 1.5, width: 11, height: 9)
                let back = CGRect(x: bounds.minX + 6, y: bounds.minY + 6, width: 10.5, height: 8.5)
                let ghost = NSBezierPath(roundedRect: back.insetBy(dx: 0.5, dy: 0.5), xRadius: 2, yRadius: 2)
                ghost.lineWidth = 1
                ghost.lineCapStyle = .round
                ghost.setLineDash([0.1, 2.2], count: 2, phase: 0)
                ghost.stroke()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                NSBezierPath(roundedRect: front.insetBy(dx: -1, dy: -1), xRadius: 3, yRadius: 3).fill()
                NSGraphicsContext.current?.compositingOperation = .sourceOver
                if on {
                    NSBezierPath(roundedRect: front, xRadius: 2.5, yRadius: 2.5).fill()
                } else {
                    let outline = NSBezierPath(roundedRect: front.insetBy(dx: lw / 2, dy: lw / 2), xRadius: 2.5, yRadius: 2.5)
                    outline.lineWidth = lw
                    outline.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Focal"
        return image
    }

    private static func halfDisk(_ r: CGRect) -> NSBezierPath {
        let p = NSBezierPath()
        p.appendArc(withCenter: CGPoint(x: r.midX, y: r.midY), radius: r.width / 2, startAngle: 90, endAngle: 270)
        p.close()
        return p
    }
}
