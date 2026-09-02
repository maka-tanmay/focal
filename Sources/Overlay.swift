import AppKit

struct WindowRef: Equatable {
    let id: CGWindowID
    let name: String
}

/// One full-screen blur window per display, ordered just below the active window,
/// so everything behind the active window looks blurred. Pinned windows get a hole
/// cut in the blur so they stay sharp too.
final class Overlay {
    var strength: CGFloat = 0.8 { didSet { refresh() } }
    /// Auto picks the strength from how many windows are cluttering the display behind the active one.
    var auto = false { didSet { refresh() } }
    var enabled = false { didSet { enabled ? start() : stop() } }
    private(set) var active: WindowRef?
    private(set) var pinned: [WindowRef] = []

    private struct Info { let id: CGWindowID; let pid: pid_t; let name: String; let bounds: CGRect }
    private var windows: [(screen: NSScreen, window: NSWindow)] = []
    private var timer: Timer?
    private var frontPID: pid_t = 0
    private var currentID: CGWindowID = 0
    private var currentAlpha: CGFloat = 0
    private var holes: [CGRect] = []
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.refresh() }
    }

    /// Keep this window sharp (max 2); call again to unpin.
    func togglePin(_ ref: WindowRef) {
        if let i = pinned.firstIndex(of: ref) {
            pinned.remove(at: i)
        } else if pinned.count < 2 {
            pinned.append(ref)
        }
        refresh()
    }

    // MARK: - Lifecycle

    private func start() {
        rebuild()
        // ponytail: 150 ms polling instead of AXObserver, so no Accessibility permission prompt.
        // Swap for kAXFocusedWindowChangedNotification if CPU ever matters.
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            self?.tick(force: false)
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
        hide()
    }

    private func refresh() {
        if enabled { tick(force: true) }
    }

    private func rebuild() {
        windows.forEach { $0.window.orderOut(nil) }
        windows = NSScreen.screens.map { ($0, makeWindow(for: $0)) }
        currentID = 0
        holes = []
        refresh()
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.alphaValue = 0
        w.level = .normal
        w.ignoresMouseEvents = true
        w.hasShadow = false
        w.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        let blur = NSVisualEffectView(frame: w.contentView!.bounds)
        blur.autoresizingMask = [.width, .height]
        blur.blendingMode = .behindWindow
        blur.material = .hudWindow
        blur.state = .active
        w.contentView = blur
        return w
    }

    // MARK: - Tracking

    /// On-screen normal-layer windows, front to back, in CoreGraphics (top-left origin) coordinates.
    private func visibleWindows() -> [Info] {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[CFString: Any]] ?? []
        return list.compactMap { w in
            guard w[kCGWindowLayer] as? Int == 0,
                  let pid = w[kCGWindowOwnerPID] as? pid_t, pid != ownPID,
                  let id = w[kCGWindowNumber] as? CGWindowID,
                  let dict = w[kCGWindowBounds] as? [String: CGFloat],
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  bounds.width > 50, bounds.height > 50 // skip helper/tooltip windows
            else { return nil }
            return Info(id: id, pid: pid, name: w[kCGWindowOwnerName] as? String ?? "Window", bounds: bounds)
        }
    }

    private func tick(force: Bool) {
        // Remember the last real front app so the menu (which makes Focal front) doesn't disturb state.
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, pid != ownPID { frontPID = pid }
        guard frontPID != 0 else { return }

        let list = visibleWindows()
        pinned.removeAll { p in !list.contains { $0.id == p.id } } // forget closed windows
        guard let act = list.first(where: { $0.pid == frontPID }) else {
            active = nil
            hide()
            return
        }
        active = WindowRef(id: act.id, name: act.name)

        let center = CGPoint(x: act.bounds.midX, y: act.bounds.midY)
        let screen = windows.first { $0.screen.cgFrame.contains(center) }?.screen ?? windows.first?.screen
        guard let screen else { return }
        if act.bounds.contains(screen.cgFrame) { hide(); return } // full screen: nothing to blur

        if force || act.id != currentID {
            currentID = act.id
            for (s, w) in windows {
                if s == screen {
                    w.order(.below, relativeTo: Int(act.id)) // blur everything behind the active window
                } else {
                    w.orderFront(nil)                        // other displays: blur everything
                }
            }
        }

        let isPinned = { (w: Info) in self.pinned.contains { $0.id == w.id } }
        let newHoles = list.filter { $0.id != act.id && isPinned($0) }.map(\.bounds)
        if newHoles != holes {
            holes = newHoles
            applyMask()
        }

        let clutter = list.filter {
            $0.id != act.id && !isPinned($0) && screen.cgFrame.contains(CGPoint(x: $0.bounds.midX, y: $0.bounds.midY))
        }.count
        let target = auto ? autoStrength(clutter: clutter) : strength
        if force || target != currentAlpha { fade(to: target) }
    }

    private func autoStrength(clutter: Int) -> CGFloat {
        switch clutter {
        case 0: return 0
        case 1: return 0.4
        case 2: return 0.7
        default: return 1
        }
    }

    // MARK: - Drawing

    /// Cuts holes in each display's blur for pinned windows.
    private func applyMask() {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        for (screen, w) in windows {
            let blur = w.contentView as! NSVisualEffectView
            let local = holes
                .filter { $0.intersects(screen.cgFrame) }
                .map { r in
                    NSRect(x: r.minX - screen.frame.minX, y: mainHeight - r.maxY - screen.frame.minY,
                           width: r.width, height: r.height)
                }
            guard !local.isEmpty else { blur.maskImage = nil; continue }
            let size = w.frame.size
            blur.maskImage = NSImage(size: size, flipped: false) { _ in
                NSColor.black.setFill()
                NSRect(origin: .zero, size: size).fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                local.forEach { NSBezierPath(roundedRect: $0, xRadius: 10, yRadius: 10).fill() }
                return true
            }
        }
    }

    private func hide() {
        currentID = 0
        currentAlpha = 0
        windows.forEach { $0.window.alphaValue = 0; $0.window.orderOut(nil) }
    }

    private func fade(to alpha: CGFloat) {
        currentAlpha = alpha
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.3
            windows.forEach { $0.window.animator().alphaValue = alpha }
        }
    }
}

private extension NSScreen {
    /// Frame in CoreGraphics coordinates (origin at top-left of the main display).
    var cgFrame: CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? frame.height
        return CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
