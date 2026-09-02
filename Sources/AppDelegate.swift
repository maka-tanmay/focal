import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate!

    private let overlay = Overlay()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let slider = NSSlider(value: 0.8, minValue: 0.2, maxValue: 1, target: nil, action: nil)
    private let defaults = UserDefaults.standard

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_: Notification) {
        overlay.strength = defaults.object(forKey: "strength") as? CGFloat ?? 0.8
        overlay.auto = defaults.bool(forKey: "auto")
        overlay.enabled = defaults.object(forKey: "enabled") as? Bool ?? true

        slider.doubleValue = overlay.strength
        slider.isContinuous = true
        slider.target = self
        slider.action = #selector(sliderChanged)

        // Left-click toggles instantly; right-click (or ⌃-click) opens the menu.
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menu.delegate = self
        updateIcon()
        registerHotKey()
    }

    // MARK: - Actions

    @objc func toggle() {
        overlay.enabled.toggle()
        defaults.set(overlay.enabled, forKey: "enabled")
        updateIcon()
    }

    @objc private func statusClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else {
            toggle()
        }
    }

    @objc private func sliderChanged() {
        overlay.strength = slider.doubleValue
        defaults.set(overlay.strength, forKey: "strength")
    }

    @objc private func toggleAuto() {
        overlay.auto.toggle()
        defaults.set(overlay.auto, forKey: "auto")
    }

    @objc private func togglePin(_ sender: NSMenuItem) {
        overlay.togglePin(sender.representedObject as! WindowRef)
    }

    @objc private func toggleLoginItem() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSLog("Login item: \(error)")
        }
    }

    private func updateIcon() {
        let name = overlay.enabled ? "circle.lefthalf.filled" : "circle"
        item.button?.image = NSImage(systemSymbolName: name, accessibilityDescription: "Focal")
        item.button?.toolTip = "Focal: click to toggle, right-click for options"
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let on = NSMenuItem(title: "Blur Background", action: #selector(toggle), keyEquivalent: "f")
        on.keyEquivalentModifierMask = [.control, .option, .command]
        on.state = overlay.enabled ? .on : .off
        menu.addItem(on)
        menu.addItem(.separator())

        slider.isEnabled = !overlay.auto
        menu.addItem(sliderItem())
        let auto = NSMenuItem(title: "Auto Strength", action: #selector(toggleAuto), keyEquivalent: "")
        auto.state = overlay.auto ? .on : .off
        auto.toolTip = "Blur harder the more windows are behind the active one; off when there's nothing to hide"
        menu.addItem(auto)
        menu.addItem(.separator())

        let header = NSMenuItem(title: "Keep Sharp (up to 2)", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for ref in overlay.pinned {
            let pin = NSMenuItem(title: ref.name, action: #selector(togglePin), keyEquivalent: "")
            pin.state = .on
            pin.representedObject = ref
            menu.addItem(pin)
        }
        if let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 {
            let pin = NSMenuItem(title: "Keep “\(ref.name)” Window Sharp", action: #selector(togglePin), keyEquivalent: "")
            pin.representedObject = ref
            menu.addItem(pin)
        }
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Focal", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
    }

    private func sliderItem() -> NSMenuItem {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        let label = NSTextField(labelWithString: "Blur")
        label.frame = NSRect(x: 14, y: 6, width: 40, height: 17)
        slider.frame = NSRect(x: 56, y: 4, width: 150, height: 20)
        view.addSubview(label)
        view.addSubview(slider)
        let item = NSMenuItem()
        item.view = view
        return item
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
