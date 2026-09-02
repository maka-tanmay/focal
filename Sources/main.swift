import AppKit
import SwiftUI

let app = NSApplication.shared

if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), CommandLine.arguments.count > i + 1 {
    // Dev only: `Focal --snapshot <dir>` renders the real panel to panel-light.png / panel-dark.png and quits.
    // The window is shown briefly on screen and made key so controls draw in their active (accent) state.
    let dir = CommandLine.arguments[i + 1]
    let overlay = Overlay()
    overlay.enabled = true
    app.setActivationPolicy(.regular)
    func snap(_ name: String, _ appearance: NSAppearance.Name, then: @escaping () -> Void) {
        let root = PopoverView(overlay: overlay, showTip: false)
            .background(Color(nsColor: .windowBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 18))
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
                try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/panel-\(name).png"))
            } catch { print("snapshot failed: \(error)") }
            window.orderOut(nil)
            then()
        }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { // let one tick find the active window
        snap("light", .aqua) { snap("dark", .darkAqua) { exit(0) } }
    }
    app.run()
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon
app.run()
