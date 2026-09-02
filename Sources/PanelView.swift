import SwiftUI

/// The menu bar dropdown, built like Control Center: a dark glass sheet holding individual glass tiles.
struct PanelView: View {
    @ObservedObject var overlay: Overlay
    @ObservedObject var prefs: Prefs
    let openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        tiles
            .padding(12)
            .frame(width: 300)
    }

    @ViewBuilder private var tiles: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) { stack }
        } else {
            stack
        }
    }

    private var stack: some View {
        VStack(spacing: 10) {
            toggleTile
            strengthTile
            fullScreenTile
            if !overlay.pinned.isEmpty || candidate != nil { pinsTile }
            HStack(spacing: 10) {
                Button("Settings…", action: openSettings).panelButton()
                Button("Quit") { NSApp.terminate(nil) }.panelButton()
            }
            .padding(.top, 2)
        }
    }

    // MARK: Tiles

    /// Capsule like the Wi-Fi tile: accent circle when on, title, state.
    private var toggleTile: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.enabled.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(nsImage: prefs.iconStyle.image(on: true))
                    .renderingMode(.template).resizable().interpolation(.high)
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(overlay.enabled ? Color.accentColor : Color.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Focal").font(.system(size: 13, weight: .semibold))
                    Text(overlay.enabled ? "On" : "Off").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassTile(Capsule(), interactive: true)
        .help(overlay.enabled ? "Click to pause" : "Click to resume")
        .accessibilityLabel(overlay.enabled ? "Focal is on. Pause" : "Focal is off. Resume")
    }

    /// Like the Display tile: title, thin white slider between a small and a large glyph.
    private var strengthTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Strength").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                    .font(.system(size: 12)).foregroundStyle(.secondary).monospacedDigit()
            }
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 11))
                ThinSlider(value: $overlay.strength, range: 0.2...1, disabled: overlay.auto)
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 17))
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.auto.toggle() }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(overlay.auto ? Color.accentColor : Color.white.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .help(overlay.auto ? "Auto strength is on. Click to set it yourself." : "Let Focal pick the strength")
                .accessibilityLabel("Auto strength")
                .accessibilityAddTraits(overlay.auto ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .glassTile(RoundedRectangle(cornerRadius: 20))
    }

    /// Capsule like the Focus tile: leave full-screen apps alone, or blur inside them too.
    private var fullScreenTile: some View {
        Button {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.skipFullScreen.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "macwindow")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(overlay.skipFullScreen ? Color.accentColor : Color.white.opacity(0.18)))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Full-screen apps").font(.system(size: 13, weight: .semibold))
                    Text(overlay.skipFullScreen ? "Left sharp" : "Blurred too").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassTile(Capsule(), interactive: true)
        .help(overlay.skipFullScreen ? "Full-screen apps are never blurred. Click to blur inside them too." : "Click to leave full-screen apps alone")
        .accessibilityLabel(overlay.skipFullScreen ? "Full-screen apps are left sharp" : "Full-screen apps are blurred too")
    }

    private var pinsTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep sharp").font(.system(size: 13, weight: .semibold))
            ForEach(overlay.pinned, id: \.id) { ref in
                row(ref) { Button("Unpin") { pin(ref) }.controlSize(.small).panelButton() }
            }
            if let ref = candidate {
                row(ref) { Button("Pin") { pin(ref) }.controlSize(.small).panelButton(prominent: true) }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassTile(RoundedRectangle(cornerRadius: 20))
    }

    private var candidate: WindowRef? {
        guard let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 else { return nil }
        return ref
    }

    private func row<Action: View>(_ ref: WindowRef, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: ref.icon).resizable().frame(width: 22, height: 22)
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

/// Control Center's thin slider: white fill on a translucent track, no knob, drag anywhere.
struct ThinSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let disabled: Bool

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let fraction = (value - range.lowerBound) / span
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.22)).frame(height: 5)
                Capsule().fill(Color.white).frame(width: max(5, geo.size.width * fraction), height: 5)
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(max(g.location.x / geo.size.width, 0), 1)
                value = range.lowerBound + f * span
            })
        }
        .frame(height: 24)
        .opacity(disabled ? 0.35 : 1)
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
    /// One Control Center tile: Liquid Glass with its own rim on macOS 26, thin material with a rim elsewhere.
    @ViewBuilder func glassTile<S: InsettableShape>(_ shape: S, interactive: Bool = false) -> some View {
        // A faint white rim keeps every tile visible over black, the way Control Center's tiles read.
        if #available(macOS 26.0, *) {
            glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.14)))
        } else {
            background(.ultraThinMaterial, in: shape)
                .overlay(shape.strokeBorder(.white.opacity(0.18)))
        }
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
