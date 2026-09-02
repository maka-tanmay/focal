import SwiftUI

/// The menu bar dropdown, Control Center style: toggle tile, thick strength slider, pins, footer.
struct PanelView: View {
    @ObservedObject var overlay: Overlay
    @ObservedObject var prefs: Prefs
    let openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 8) {
            toggleTile
            strengthTile
            if !overlay.pinned.isEmpty || candidate != nil { pinsTile }
            HStack {
                Button("Settings…", action: openSettings).panelButton()
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.panelButton()
            }
            .padding(.top, 4)
        }
        .padding(10)
        .frame(width: 300)
    }

    // MARK: Tiles

    private var toggleTile: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.enabled.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(nsImage: prefs.iconStyle.image(on: true))
                    .renderingMode(.template).resizable().interpolation(.high)
                    .frame(width: 16, height: 16)
                    .foregroundStyle(overlay.enabled ? .white : .primary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(overlay.enabled ? Color.accentColor : tileFill))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Focal").font(.system(size: 13, weight: .semibold))
                    Text(overlay.enabled ? "On" : "Paused").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: 14).fill(tileFill))
        .help(overlay.enabled ? "Click to pause" : "Click to resume")
        .accessibilityLabel(overlay.enabled ? "Focal is on. Pause" : "Focal is paused. Resume")
    }

    private var strengthTile: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Strength").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                    .font(.system(size: 11)).foregroundStyle(.secondary).monospacedDigit()
                Toggle("Auto", isOn: $overlay.auto).toggleStyle(.button).controlSize(.mini).panelButton()
            }
            ThickSlider(value: $overlay.strength, range: 0.2...1, disabled: overlay.auto)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tileFill))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: overlay.auto)
    }

    private var pinsTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep sharp").font(.system(size: 11)).foregroundStyle(.secondary)
            ForEach(overlay.pinned, id: \.id) { ref in
                row(ref) { Button("Unpin") { pin(ref) }.controlSize(.small).panelButton() }
            }
            if let ref = candidate {
                row(ref) { Button("Pin") { pin(ref) }.controlSize(.small).panelButton(prominent: true) }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14).fill(tileFill))
    }

    private var tileFill: Color { scheme == .dark ? .white.opacity(0.12) : .black.opacity(0.06) }

    private var candidate: WindowRef? {
        guard let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 else { return nil }
        return ref
    }

    private func row<Action: View>(_ ref: WindowRef, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: ref.icon).resizable().frame(width: 20, height: 20)
            Text(ref.name).font(.system(size: 13)).lineLimit(1)
            Spacer(minLength: 8)
            action()
        }
        .transition(.opacity)
    }

    private func pin(_ ref: WindowRef) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.togglePin(ref) }
    }
}

/// Control Center's brightness-style slider: a thick capsule with the glyph riding inside the fill.
struct ThickSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let disabled: Bool
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let fraction = (value - range.lowerBound) / span
            ZStack(alignment: .leading) {
                Capsule().fill(scheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.1))
                Capsule().fill(Color.white).frame(width: max(28, geo.size.width * fraction))
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.black.opacity(0.75))
                    .padding(.leading, 8)
            }
            .contentShape(Capsule())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(max(g.location.x / geo.size.width, 0), 1)
                value = range.lowerBound + f * span
            })
        }
        .frame(height: 28)
        .opacity(disabled ? 0.4 : 1)
        .allowsHitTesting(!disabled)
        .accessibilityElement()
        .accessibilityLabel("Strength")
        .accessibilityValue("\(Int(value * 100)) percent")
        .accessibilityAdjustableAction { direction in
            let step: CGFloat = 0.1
            value = min(max(value + (direction == .increment ? step : -step), range.lowerBound), range.upperBound)
        }
    }
}

private extension View {
    /// Liquid Glass buttons on macOS 26, bordered elsewhere.
    @ViewBuilder func panelButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { buttonStyle(.glassProminent) } else { buttonStyle(.glass) }
        } else {
            if prominent { buttonStyle(.borderedProminent) } else { buttonStyle(.bordered) }
        }
    }
}
