import AppKit
import SwiftUI
import ScreenCaptureKit

let app = NSApplication.shared

if let i = CommandLine.arguments.firstIndex(of: "--capture"), CommandLine.arguments.count > i + 3 {
    // Dev only: `Focal --capture <dir> <count> <interval>` saves full-screen PNGs (frame-0001.png …) for README shots.
    // macOS asks once to let Focal record the screen.
    let dir = CommandLine.arguments[i + 1]
    let count = Int(CommandLine.arguments[i + 2]) ?? 1
    let interval = Double(CommandLine.arguments[i + 3]) ?? 1
    if #available(macOS 14.0, *) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = content.displays.first else { print("no display"); exit(1) }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                let config = SCStreamConfiguration()
                config.width = display.width * 2
                config.height = display.height * 2
                config.showsCursor = true
                for n in 1...count {
                    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    let rep = NSBitmapImageRep(cgImage: image)
                    try rep.representation(using: .png, properties: [:])!
                        .write(to: URL(fileURLWithPath: String(format: "%@/frame-%04d.png", dir, n)))
                    if n < count { try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000)) }
                }
                print("captured \(count)")
                exit(0)
            } catch {
                print("capture failed: \(error)")
                exit(1)
            }
        }
        app.run()
    } else {
        print("needs macOS 14"); exit(1)
    }
}

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
    // Dev only: `Focal --snapshot <dir>` renders the real panel to panel-light.png / panel-dark.png and quits.
    // The window is shown briefly on screen and made key so controls draw in their active (accent) state.
    let dir = CommandLine.arguments[i + 1]
    let overlay = Overlay()
    overlay.enabled = true
    app.setActivationPolicy(.regular)
    func snap<V: View>(_ name: String, _ appearance: NSAppearance.Name, _ content: V, then: @escaping () -> Void) {
        let root = content
            .environment(\.controlActiveState, .key) // shell-launched apps cannot activate; draw controls as active anyway
            .background(name == "panel-glass" ? Color(red: 0.16, green: 0.16, blue: 0.18) : Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.28), radius: 18, y: 8)
            .padding(32)
        let view = NSHostingView(rootView: root)
        view.frame.size = view.fittingSize
        let window = NSWindow(contentRect: view.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: appearance)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: rep)
            do {
                try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
            } catch { print("snapshot failed: \(error)") }
            window.orderOut(nil)
            then()
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { // let one tick find the active window
        let prefs = Prefs()
        PanelTheme.flatGlass = true
        prefs.panelStyle = .glass
        snap("panel-glass", .darkAqua, PanelView(overlay: overlay, prefs: prefs, openSettings: {})) {
            prefs.panelStyle = .soft
            snap("panel-soft", .aqua, PanelView(overlay: overlay, prefs: prefs, openSettings: {})) {
                prefs.panelStyle = .leather
                snap("panel-leather", .darkAqua, PanelView(overlay: overlay, prefs: prefs, openSettings: {})) {
                    snap("settings-welcome", .darkAqua, WelcomeTab(overlay: overlay, prefs: prefs)) {
                        snap("settings-appearance", .darkAqua, AppearanceTab(prefs: prefs)) { exit(0) }
                    }
                }
            }
        }
    }
    app.run()
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
