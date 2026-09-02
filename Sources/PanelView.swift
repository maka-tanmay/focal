import SwiftUI

/// The menu bar dropdown, Control Center style: a big toggle tile, a strength tile, pins, footer.
struct PanelView: View {
    @ObservedObject var overlay: Overlay
    @ObservedObject var prefs: Prefs
    let openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            toggleTile
            strengthTile
            if !overlay.pinned.isEmpty || candidate != nil { pinsTile }
            HStack {
                Button("Settings…", action: openSettings).panelButton()
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.panelButton()
            }
            .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 300)
    }

    // MARK: Tiles

    private var toggleTile: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.enabled.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: prefs.iconStyle.image(on: true))
                    .renderingMode(.template).resizable().interpolation(.high)
                    .frame(width: 22, height: 22)
                    .foregroundStyle(overlay.enabled ? .white : .primary)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(overlay.enabled ? Color.accentColor : Color.primary.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Focal").font(.headline)
                    Text(overlay.enabled ? "On · blurring behind the active window" : "Paused")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .tile()
        .help(overlay.enabled ? "Click to pause" : "Click to resume")
        .accessibilityLabel(overlay.enabled ? "Focal is on. Pause" : "Focal is paused. Resume")
    }

    private var strengthTile: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled").foregroundStyle(.secondary)
                Slider(value: $overlay.strength, in: 0.2...1)
                    .disabled(overlay.auto)
                    .opacity(overlay.auto ? 0.4 : 1)
                Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                    .font(.callout).foregroundStyle(.secondary).monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
            HStack {
                Text("Strength").font(.callout)
                Spacer()
                Toggle("Auto", isOn: $overlay.auto).toggleStyle(.button).controlSize(.small).panelButton()
            }
        }
        .padding(12)
        .tile()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: overlay.auto)
    }

    private var pinsTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep sharp").font(.caption).foregroundStyle(.secondary)
            ForEach(overlay.pinned, id: \.id) { ref in
                row(ref) { Button("Unpin") { pin(ref) }.controlSize(.small).panelButton() }
            }
            if let ref = candidate {
                row(ref) { Button("Pin") { pin(ref) }.controlSize(.small).panelButton(prominent: true) }
            }
        }
        .padding(12)
        .tile()
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
        .transition(.opacity)
    }

    private func pin(_ ref: WindowRef) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.togglePin(ref) }
    }
}

private extension View {
    /// Translucent tile inside the glass panel (Control Center groups its controls the same way).
    func tile() -> some View {
        background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.07)))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.06)))
    }

    /// Liquid Glass buttons on macOS 26, bordered elsewhere.
    @ViewBuilder func panelButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}
