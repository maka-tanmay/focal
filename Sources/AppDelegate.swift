import AppKit
import Carbon
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    static private(set) var shared: AppDelegate!

    private let overlay = Overlay()
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let defaults = UserDefaults.standard
    private var bag = Set<AnyCancellable>()
    private lazy var popover: NSPopover = {
        let p = NSPopover()
        p.behavior = .transient
        p.appearance = NSAppearance(named: .darkAqua)
        p.contentViewController = NSHostingController(
            rootView: PopoverView(overlay: overlay, showTip: !defaults.bool(forKey: "onboarded"))
        )
        return p
    }()

    override init() {
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_: Notification) {
        overlay.$enabled.sink { [weak self] on in self?.updateIcon(on) }.store(in: &bag)
        overlay.enabled = defaults.object(forKey: "enabled") as? Bool ?? true

        // Click opens the panel; ⌥-click pauses/resumes instantly.
        item.button?.target = self
        item.button?.action = #selector(statusClicked)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        registerHotKey()

        if !defaults.bool(forKey: "onboarded") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [self] in
                showPopover()
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
        } else if popover.isShown {
            popover.close()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = item.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func updateIcon(_ on: Bool) {
        item.button?.image = NSImage(systemSymbolName: on ? "circle.lefthalf.filled" : "circle.dashed",
                                     accessibilityDescription: "Focal")
        item.button?.toolTip = on ? "Focal is blurring. Click for options, ⌥-click to pause."
                                  : "Focal is paused. Click for options, ⌥-click to resume."
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
