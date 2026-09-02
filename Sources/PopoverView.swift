import SwiftUI
import ServiceManagement

struct PopoverView: View {
    @ObservedObject var overlay: Overlay
    let showTip: Bool
    @State private var login = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: overlay.enabled ? "circle.lefthalf.filled" : "circle.dashed")
                    .font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focal").font(.headline)
                    Text(overlay.enabled ? "Blurring everything behind your active window" : "Paused. Nothing is blurred.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Blur", isOn: $overlay.enabled).toggleStyle(.switch).labelsHidden()
            }

            if showTip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                    Text("Click any window and everything behind it softens. Click the ◐ icon in your menu bar any time to open this panel. ⌥-click it, or press ⌃⌥⌘F, to pause instantly.")
                }
                .font(.caption)
                .padding(10)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Blur strength").font(.subheadline.weight(.semibold))
                    Spacer()
                    Toggle("Auto", isOn: $overlay.auto).toggleStyle(.checkbox)
                }
                Slider(value: $overlay.strength, in: 0.2...1).disabled(overlay.auto)
                Text(overlay.auto
                     ? "Auto: stronger the more windows sit behind the active one, off when there's nothing to hide."
                     : "Drag to taste. Auto lets Focal decide.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Also keep sharp").font(.subheadline.weight(.semibold))
                Text("Up to two extra windows stay clear next to the active one.")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(overlay.pinned, id: \.id) { ref in
                    HStack {
                        Image(systemName: "pin.fill").foregroundStyle(.secondary)
                        Text(ref.name)
                        Spacer()
                        Button { overlay.togglePin(ref) } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Stop keeping this window sharp")
                    }
                }
                if let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 {
                    Button("Keep “\(ref.name)” window sharp") { overlay.togglePin(ref) }
                        .help("Pins the window you were just using")
                }
            }

            Divider()

            HStack {
                Toggle("Launch at login", isOn: $login).toggleStyle(.checkbox)
                    .onChange(of: login) { on in
                        let service = SMAppService.mainApp
                        do {
                            if on { try service.register() } else { try service.unregister() }
                        } catch {
                            login = service.status == .enabled
                        }
                    }
                Spacer()
                Text("⌃⌥⌘F").font(.caption.monospaced()).foregroundStyle(.secondary)
                    .help("Global shortcut to toggle Focal")
                Button("Quit") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
