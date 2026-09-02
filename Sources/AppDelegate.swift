import AppKit
import Carbon
import Combine
import SwiftUI

/// Borderless panel that can take keyboard focus without activating the app (like Control Center).
final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private let overlay = Overlay()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let defaults = UserDefaults.standard
    private var bag = Set<AnyCancellable>()
    private var monitors: [Any] = []
    private lazy var host = NSHostingView(
        rootView: PopoverView(overlay: overlay, showTip: !defaults.bool(forKey: "onboarded"))
    )
    private lazy var panel: NSPanel = makePanel()

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_: Notification) {
        overlay.$enabled.sink { [weak self] on in self?.updateIcon(on) }.store(in: &bag)
        overlay.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        // Content grows/shrinks (pins, tip): keep the panel fitted.
        overlay.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in DispatchQueue.main.async { self?.fitPanel() } }
            .store(in: &bag)

        // Click opens the panel; ⌥-click pauses/resumes instantly.
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        registerHotKey()

        if !defaults.bool(forKey: "onboarded") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                showPanel()
                defaults.set(true, forKey: "onboarded")
            }
        }
    }

    @objc func toggle() {
        overlay.enabled.toggle()
    }

    @objc private func statusClicked() {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            toggle()
        } else if panel.isVisible {
            closePanel()
        } else {
            showPanel()
        }
    }

    // MARK: - Panel (Control Center style: arrow-less glass sheet under the menu bar item)

    private func makePanel() -> NSPanel {
        let p = GlassPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .popUpMenu
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary, .transient]
        p.animationBehavior = .utilityWindow

        host.translatesAutoresizingMaskIntoConstraints = false
        let glass: NSView
        if #available(macOS 26.0, *) {
            let g = NSGlassEffectView()
            g.cornerRadius = 18
            g.contentView = host
            glass = g
        } else {
            let v = NSVisualEffectView()
            v.material = .popover
            v.blendingMode = .behindWindow
            v.state = .active
            v.wantsLayer = true
            v.layer?.cornerRadius = 18
            v.layer?.masksToBounds = true
            v.addSubview(host)
            glass = v
        }
        glass.translatesAutoresizingMaskIntoConstraints = false
        p.contentView = glass
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: glass.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: glass.trailingAnchor),
            host.topAnchor.constraint(equalTo: glass.topAnchor),
            host.bottomAnchor.constraint(equalTo: glass.bottomAnchor),
        ])

        // Dismiss like a system panel: click anywhere else, Escape, or losing key status.
        NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: p, queue: .main) { [weak self] _ in
            self?.closePanel()
        }
        return p
    }

    private func showPanel() {
        fitPanel()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }
        item.button?.highlight(true)
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.closePanel() } as Any,
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] e in
                guard e.keyCode == 53 else { return e } // Escape
                self?.closePanel()
                return nil
            } as Any,
        ]
    }

    private func closePanel() {
        guard panel.isVisible else { return }
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        item.button?.highlight(false)
        panel.orderOut(nil)
    }

    /// Size the panel to its content and hang it centered under the menu bar item.
    private func fitPanel() {
        guard let button = item.button, let bar = button.window else { return }
        let size = host.fittingSize
        let anchor = bar.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = bar.screen ?? NSScreen.main
        let visible = screen?.visibleFrame ?? anchor
        var x = anchor.midX - size.width / 2
        x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        let y = anchor.minY - 6 - size.height
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    // MARK: - Menu bar glyph: solid left half = sharp, dotted right half = blurred. Paused = dotted ring.

    private func updateIcon(_ on: Bool) {
        item.button?.image = glyph(on: on)
        item.button?.toolTip = on ? "Focal is blurring. Click for options, ⌥-click to pause."
                                  : "Focal is paused. Click for options, ⌥-click to resume."
    }

    private func glyph(on: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { bounds in
            let r = bounds.insetBy(dx: 2, dy: 2)
            let center = CGPoint(x: r.midX, y: r.midY)
            NSColor.black.set()
            let dots = NSBezierPath()
            dots.appendArc(withCenter: center, radius: r.width / 2 - 0.8,
                           startAngle: on ? -90 : 0, endAngle: on ? 90 : 360)
            dots.lineWidth = 1.6
            dots.lineCapStyle = .round
            dots.setLineDash([0.1, 2.6], count: 2, phase: 0)
            dots.stroke()
            if on {
                let half = NSBezierPath()
                half.appendArc(withCenter: center, radius: r.width / 2, startAngle: 90, endAngle: 270)
                half.close()
                half.fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Focal"
        return image
    }

    // MARK: - Global hotkey ⌃⌥⌘F (Carbon: works without Accessibility permission)

    private func registerHotKey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            AppDelegate.shared.toggle()
            return noErr
        }, 1, &spec, nil, nil)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(
            UInt32(kVK_ANSI_F), UInt32(cmdKey | optionKey | controlKey),
            EventHotKeyID(signature: 0x464F_434C, id: 1), // "FOCL"
            GetApplicationEventTarget(), 0, &ref
        )
    }
}
