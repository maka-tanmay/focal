import AppKit

/// One full-screen blur window per display, ordered just below the active window,
/// so everything behind the active window looks blurred.
final class Overlay {
    var strength: CGFloat = 0.8 { didSet { if enabled, current != 0 { fade(to: strength) } } }
    var enabled = false { didSet { enabled ? start() : stop() } }

    private var windows: [(screen: NSScreen, window: NSWindow)] = []
    private var timer: Timer?
    private var current: CGWindowID = 0
    private let ownPID = ProcessInfo.processInfo.processIdentifier

    init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuild() }
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick(force: true) }
    }

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
        current = 0
        fade(to: 0)
    }

    private func rebuild() {
        windows.forEach { $0.window.orderOut(nil) }
        windows = NSScreen.screens.map { ($0, makeWindow(for: $0)) }
        current = 0
        if enabled { tick(force: true) }
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

    /// Frontmost normal-layer window of the frontmost app, in screen (top-left origin) coordinates.
    private func activeWindow(pid: pid_t) -> (id: CGWindowID, bounds: CGRect)? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[CFString: Any]] ?? []
        for w in list where w[kCGWindowOwnerPID] as? pid_t == pid && w[kCGWindowLayer] as? Int == 0 {
            guard let id = w[kCGWindowNumber] as? CGWindowID,
                  let dict = w[kCGWindowBounds] as? [String: CGFloat],
                  let bounds = CGRect(dictionaryRepresentation: dict as CFDictionary),
                  bounds.width > 50, bounds.height > 50 // skip helper/tooltip windows
            else { continue }
            return (id, bounds)
        }
        return nil
    }

    private func tick(force: Bool) {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, pid != ownPID else { return }
        guard let (id, bounds) = activeWindow(pid: pid) else {
            if current != 0 { current = 0; fade(to: 0) }
            return
        }
        guard force || id != current else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        // Full-screen window: nothing to blur, and the overlay would float above it. Keep re-checking.
        if let screen = windows.first(where: { $0.screen.cgFrame.contains(center) })?.screen,
           bounds.contains(screen.cgFrame) {
            current = 0
            hide()
            return
        }
        current = id
        for (screen, w) in windows {
            if screen.cgFrame.contains(center) {
                w.order(.below, relativeTo: Int(id))   // blur everything behind the active window
            } else {
                w.orderFront(nil)                       // other displays: blur everything
            }
        }
        fade(to: strength)
    }

    private func hide() {
        windows.forEach { $0.window.alphaValue = 0; $0.window.orderOut(nil) }
    }

    private func fade(to alpha: CGFloat) {
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
