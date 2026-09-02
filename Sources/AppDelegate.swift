import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static private(set) var shared: AppDelegate!

    private let overlay = Overlay()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let defaults = UserDefaults.standard
    private let strengths: [(String, CGFloat)] = [("Light", 0.5), ("Medium", 0.8), ("Strong", 1.0)]

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_: Notification) {
        overlay.strength = defaults.object(forKey: "strength") as? CGFloat ?? 0.8
        overlay.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
        item.menu = NSMenu()
        item.menu?.delegate = self
        updateIcon()
        registerHotKey()
    }

    // MARK: - Actions

    @objc func toggle() {
        overlay.enabled.toggle()
        defaults.set(overlay.enabled, forKey: "enabled")
        updateIcon()
    }

    @objc private func setStrength(_ sender: NSMenuItem) {
        let value = strengths[sender.tag].1
        overlay.strength = value
        defaults.set(value, forKey: "strength")
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
    }

    // MARK: - Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let on = NSMenuItem(title: "Blur Background", action: #selector(toggle), keyEquivalent: "f")
        on.keyEquivalentModifierMask = [.control, .option, .command]
        on.state = overlay.enabled ? .on : .off
        menu.addItem(on)
        menu.addItem(.separator())

        for (i, (title, value)) in strengths.enumerated() {
            let s = NSMenuItem(title: title, action: #selector(setStrength), keyEquivalent: "")
            s.tag = i
            s.state = overlay.strength == value ? .on : .off
            menu.addItem(s)
        }
        menu.addItem(.separator())

        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLoginItem), keyEquivalent: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Focal", action: #selector(NSApplication.terminate), keyEquivalent: "q"))
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
