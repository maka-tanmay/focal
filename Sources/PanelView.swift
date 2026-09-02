import SwiftUI

/// The menu bar dropdown. Compact on purpose; explanations live in Settings.
struct PanelView: View {
    @ObservedObject var overlay: Overlay
    let openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Focal").font(.headline)
                Spacer()
                Toggle("Blur background", isOn: $overlay.enabled).toggleStyle(.switch).labelsHidden()
            }

            Divider()

            HStack {
                Text("Strength")
                Spacer()
                Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $overlay.strength, in: 0.2...1)
                .disabled(overlay.auto)
                .opacity(overlay.auto ? 0.4 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: overlay.auto)
            HStack {
                Text("Auto")
                Spacer()
                Toggle("Auto strength", isOn: $overlay.auto).toggleStyle(.switch).labelsHidden().controlSize(.small)
            }

            if !overlay.pinned.isEmpty || candidate != nil {
                Divider()
                Text("Keep sharp").font(.caption).foregroundStyle(.secondary)
                ForEach(overlay.pinned, id: \.id) { ref in
                    row(ref) { Button("Unpin") { pin(ref) }.buttonStyle(.bordered).controlSize(.small) }
                        .transition(.opacity)
                }
                if let ref = candidate {
                    row(ref) { Button("Pin") { pin(ref) }.buttonStyle(.borderedProminent).controlSize(.small) }
                        .transition(.opacity)
                }
            }

            Divider()

            HStack {
                Button("Settings…", action: openSettings).buttonStyle(.borderless)
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.borderless).foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private var candidate: WindowRef? {
        guard let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 else { return nil }
        return ref
    }

    private func row<Action: View>(_ ref: WindowRef, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: ref.icon).resizable().frame(width: 22, height: 22)
            Text(ref.name).lineLimit(1)
            Spacer(minLength: 8)
            action()
        }
    }

    private func pin(_ ref: WindowRef) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.togglePin(ref) }
    }
}
