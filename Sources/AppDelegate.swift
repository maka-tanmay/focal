import AppKit
import Carbon
import Combine
import SwiftUI

/// Borderless panel that can take keyboard focus without activating the app (like Control Center).
final class GlassPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    static private(set) var shared: AppDelegate!

    private let overlay = Overlay()
    private let prefs = Prefs()
    private var hotKeyRef: EventHotKeyRef?
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let defaults = UserDefaults.standard
    private var bag = Set<AnyCancellable>()
    private var monitors: [Any] = []
    private lazy var host = NSHostingView(
        rootView: PanelView(overlay: overlay, prefs: prefs) { [weak self] in
            self?.closePanel()
            self?.showSettings()
        }
    )
    private lazy var panel: NSPanel = makePanel()
    private lazy var settings: NSWindow = makeSettingsWindow()

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_: Notification) {
        overlay.$enabled.sink { [weak self] on in self?.updateIcon(on) }.store(in: &bag)
        // @Published emits before the property changes, so always use the emitted value, never re-read prefs.
        prefs.$iconStyle.dropFirst().sink { [weak self] style in
            guard let self else { return }
            self.updateIcon(self.overlay.enabled, style: style)
        }.store(in: &bag)
        prefs.$hotkey.dropFirst().sink { [weak self] hotkey in self?.registerHotKey(hotkey) }.store(in: &bag)
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
        installMainMenu()

        if !defaults.bool(forKey: "onboarded") {
            defaults.set(true, forKey: "onboarded")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in showSettings() }
        }
    }

    /// Clicking the Dock icon (visible while Settings is open) brings Settings back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showSettings()
        return true
    }

    // MARK: - Settings window (regular app with a Dock icon only while it's open)

    private func makeSettingsWindow() -> NSWindow {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        let pages: [(String, String, AnyView)] = [
            ("Welcome", "sparkles", AnyView(WelcomeTab(overlay: overlay, prefs: prefs))),
            ("General", "slider.horizontal.3", AnyView(GeneralTab(overlay: overlay))),
            ("Icon", "circle.lefthalf.filled", AnyView(IconTab(prefs: prefs))),
            ("Shortcuts", "keyboard", AnyView(ShortcutsTab(prefs: prefs))),
            ("About", "info.circle", AnyView(AboutTab())),
        ]
        for (title, symbol, view) in pages {
            let host = NSHostingController(rootView: view)
            host.sizingOptions = [.preferredContentSize]
            let item = NSTabViewItem(viewController: host)
            item.label = title
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
            tabs.addTabViewItem(item)
        }
        let w = NSWindow(contentViewController: tabs)
        w.styleMask = [.titled, .closable, .miniaturizable]
        w.toolbarStyle = .preference
        w.title = "Focal"
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()
        return w
    }

    private func showSettings() {
        NSApp.setActivationPolicy(.regular)
        settings.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        guard (notification.object as? NSWindow) == settings else { return }
        NSApp.setActivationPolicy(.accessory)
    }

    /// Minimal main menu so ⌘W / ⌘Q work while the Settings window is up.
    private func installMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        appMenu.addItem(withTitle: "Quit Focal", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        NSApp.mainMenu = main
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
        let container: NSView
        if #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = 22
            glass.contentView = host
            container = glass
        } else {
            let v = NSVisualEffectView()
            v.material = .popover
            v.blendingMode = .behindWindow
            v.state = .active
            v.wantsLayer = true
            v.layer?.cornerRadius = 22
            v.layer?.cornerCurve = .continuous
            v.layer?.masksToBounds = true
            v.addSubview(host)
            container = v
        }
        p.contentView = container
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.topAnchor.constraint(equalTo: container.topAnchor),
            host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
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
        panel.invalidateShadow()
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

    // MARK: - Menu bar icon

    private func updateIcon(_ on: Bool, style: IconStyle? = nil) {
        item.button?.image = (style ?? prefs.iconStyle).image(on: on)
        item.button?.toolTip = on ? "Focal is blurring. Click for options, ⌥-click to pause."
                                  : "Focal is paused. Click for options, ⌥-click to resume."
    }

    // MARK: - Global hotkey (Carbon: works without Accessibility permission)

    private var handlerInstalled = false

    private func registerHotKey(_ hotkey: Hotkey? = nil) {
        let hotkey = hotkey ?? prefs.hotkey
        if !handlerInstalled {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                AppDelegate.shared.toggle()
                return noErr
            }, 1, &spec, nil, nil)
            handlerInstalled = true
        }
        if let old = hotKeyRef { UnregisterEventHotKey(old); hotKeyRef = nil }
        RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers,
                            EventHotKeyID(signature: 0x464F_434C, id: 1), // "FOCL"
                            GetApplicationEventTarget(), 0, &hotKeyRef)
    }
}
