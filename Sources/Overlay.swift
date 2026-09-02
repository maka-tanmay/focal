import AppKit

struct WindowRef: Equatable {
    let id: CGWindowID
    let pid: pid_t
    let name: String
    /// The app's real icon, or the generic app icon if the process can't be resolved.
    var icon: NSImage {
        NSRunningApplication(processIdentifier: pid)?.icon
            ?? NSWorkspace.shared.icon(for: .applicationBundle)
    }
}

/// One full-screen blur window per display, ordered just below the active window,
/// so everything behind the active window looks blurred. Pinned windows get a hole
/// cut in the blur so they stay sharp too.
final class Overlay: ObservableObject {
    private let defaults = UserDefaults.standard

    @Published var strength: CGFloat = UserDefaults.standard.object(forKey: "strength") as? CGFloat ?? 0.8 {
        didSet { defaults.set(strength, forKey: "strength"); refresh() }
    }
    /// Auto picks the strength from how many windows are cluttering the display behind the active one.
    @Published var auto = UserDefaults.standard.bool(forKey: "auto") {
        didSet { defaults.set(auto, forKey: "auto"); refresh() }
    }
    /// Set after launch; the initial value is stored under "enabled" (default on).
    @Published var enabled = false {
        didSet { defaults.set(enabled, forKey: "enabled"); enabled ? start() : stop() }
    }
    /// Leave full-screen apps alone (default). Off lets Focal blur inside full-screen Spaces, e.g. Split View.
    @Published var skipFullScreen = UserDefaults.standard.object(forKey: "skipFullScreen") as? Bool ?? true {
        didSet { defaults.set(skipFullScreen, forKey: "skipFullScreen"); refresh() }
    }
    @Published private(set) var active: WindowRef?
    @Published private(set) var pinned: [WindowRef] = []

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
        // Swiping Spaces: drop the overlay instantly, then re-place it in the new Space on the next tick.
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.hide(); self?.refresh() }
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
        // moveToActiveSpace (not canJoinAllSpaces) so the overlay doesn't ride along during a swipe.
        w.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient, .ignoresCycle]
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

    /// The front app's real window. Browsers keep toolbar strips and popups as extra normal-level windows,
    /// some parked off-screen, some lying on top of the main window; those must not be mistaken for it.
    private func mainWindow(of pid: pid_t, in list: [Info]) -> Info? {
        let screens = NSScreen.screens.map(\.cgFrame)
        func visibleFraction(_ r: CGRect) -> CGFloat {
            let shown = screens.reduce(CGFloat(0)) { $0 + r.intersection($1).area }
            return r.area > 0 ? shown / r.area : 0
        }
        let mine = list.filter { $0.pid == pid && visibleFraction($0.bounds) >= 0.5 }
        guard let front = mine.first else { return nil }
        // A small window sitting entirely inside a bigger sibling is a toolbar, sheet or popup: use the sibling.
        if let parent = mine.first(where: { $0.id != front.id && $0.bounds.contains(front.bounds) && front.bounds.area < 0.5 * $0.bounds.area }) {
            return parent
        }
        return front
    }

    private func tick(force: Bool) {
        // Remember the last real front app so the menu (which makes Focal front) doesn't disturb state.
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier, pid != ownPID { frontPID = pid }
        guard frontPID != 0 else { return }

        let list = visibleWindows()
        let alive = pinned.filter { p in list.contains { $0.id == p.id } } // forget closed windows
        if alive != pinned { pinned = alive }
        guard let act = mainWindow(of: frontPID, in: list) else {
            if active != nil { active = nil }
            hide()
            return
        }
        let ref = WindowRef(id: act.id, pid: act.pid, name: act.name)
        if ref != active { active = ref }

        let center = CGPoint(x: act.bounds.midX, y: act.bounds.midY)
        let screen = windows.first { $0.screen.cgFrame.contains(center) }?.screen ?? windows.first?.screen
        guard let screen else { return }
        // Full-screen (or maximized under the menu bar / notch): nothing worth blurring behind it.
        let fillsScreen = act.bounds.width >= screen.cgFrame.width - 2 && act.bounds.height >= screen.cgFrame.height - 80
        if fillsScreen && skipFullScreen { hide(); return }

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

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

private extension NSScreen {
    /// Frame in CoreGraphics coordinates (origin at top-left of the main display).
    var cgFrame: CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? frame.height
        return CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
