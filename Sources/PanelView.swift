import SwiftUI

/// The menu bar dropdown: toggle tile, strength, full-screen tile, pins, footer. Material comes from Prefs.
struct PanelView: View {
    @ObservedObject var overlay: Overlay
    @ObservedObject var prefs: Prefs
    let openSettings: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var style: PanelStyle { prefs.panelStyle }
    private var theme: PanelTheme { PanelTheme(style: style) }

    var body: some View {
        VStack(spacing: style == .glass ? 10 : 14) {
            capsuleTile(icon: AnyView(iconGlyph), title: "Focal", state: overlay.enabled ? "On" : "Off", on: overlay.enabled,
                        help: overlay.enabled ? "Click to pause" : "Click to resume") {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.enabled.toggle() }
            }
            strengthTile
            capsuleTile(icon: AnyView(Image(systemName: "macwindow").font(.system(size: 16, weight: .medium))),
                        title: "Full-screen apps", state: overlay.skipFullScreen ? "Left sharp" : "Blurred too", on: overlay.skipFullScreen,
                        help: overlay.skipFullScreen ? "Full-screen apps are never blurred. Click to blur inside them too." : "Click to leave full-screen apps alone") {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.skipFullScreen.toggle() }
            }
            if !overlay.pinned.isEmpty || candidate != nil { pinsTile }
            HStack(spacing: 10) {
                PanelButton(title: "Settings…", style: style, action: openSettings)
                PanelButton(title: "Quit", style: style) { NSApp.terminate(nil) }
            }
            .padding(.top, 2)
        }
        .padding(style == .glass ? 12 : 16)
        .frame(width: 300)
        .panelSheet(style)
    }

    private var iconGlyph: some View {
        Image(nsImage: prefs.iconStyle.image(on: true))
            .renderingMode(.template).resizable().interpolation(.high)
            .frame(width: 18, height: 18)
    }

    // MARK: Tiles

    /// Capsule like the Wi-Fi tile: circle that lights up when on, title, state.
    private func capsuleTile(icon: AnyView, title: String, state: String, on: Bool, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon.foregroundStyle(theme.glyph(on: on))
                    .frame(width: 40, height: 40)
                    .background(theme.circle(on: on))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.text)
                    Text(state).font(.system(size: 12)).foregroundStyle(theme.subtext)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 9)
            .frame(maxWidth: .infinity)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .panelTile(Capsule(), style: style)
        .help(help)
        .accessibilityLabel("\(title): \(state)")
    }

    private var strengthTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Strength").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.text)
                Spacer()
                Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                    .font(style == .leather ? .system(size: 12, design: .monospaced) : .system(size: 12))
                    .foregroundStyle(theme.value).monospacedDigit()
            }
            HStack(spacing: 10) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 11)).foregroundStyle(theme.subtext)
                ThinSlider(value: $overlay.strength, range: 0.2...1, disabled: overlay.auto, style: style)
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 17)).foregroundStyle(theme.text)
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.auto.toggle() }
                } label: {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(theme.glyph(on: overlay.auto))
                        .frame(width: 28, height: 28)
                        .background(theme.circle(on: overlay.auto))
                }
                .buttonStyle(.plain)
                .help(overlay.auto ? "Auto strength is on. Click to set it yourself." : "Let Focal pick the strength")
                .accessibilityLabel("Auto strength")
                .accessibilityAddTraits(overlay.auto ? .isSelected : [])
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .panelTile(RoundedRectangle(cornerRadius: 20), style: style)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: overlay.auto)
    }

    private var pinsTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Keep sharp").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.text)
            ForEach(overlay.pinned, id: \.id) { ref in
                row(ref) { PanelButton(title: "Unpin", style: style) { pin(ref) } }
            }
            if let ref = candidate {
                row(ref) { PanelButton(title: "Pin", style: style, prominent: true) { pin(ref) } }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .panelTile(RoundedRectangle(cornerRadius: 20), style: style)
    }

    private var candidate: WindowRef? {
        guard let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 else { return nil }
        return ref
    }

    private func row<Action: View>(_ ref: WindowRef, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: ref.icon).resizable().frame(width: 22, height: 22)
            Text(ref.name).font(.system(size: 13)).foregroundStyle(theme.text).lineLimit(1)
            Spacer(minLength: 8)
            action()
        }
        .transition(.opacity)
    }

    private func pin(_ ref: WindowRef) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.togglePin(ref) }
    }
}

/// Strength slider in each material: thin white on glass, inset groove with a raised thumb on soft, amber groove on leather.
struct ThinSlider: View {
    @Binding var value: CGFloat
    let range: ClosedRange<CGFloat>
    let disabled: Bool
    var style: PanelStyle = .glass
    var compact = false

    private var trackHeight: CGFloat { style == .glass ? 5 : (compact ? 6 : 10) }
    private var thumb: CGFloat { compact ? 12 : 20 }

    var body: some View {
        GeometryReader { geo in
            let span = range.upperBound - range.lowerBound
            let fraction = (value - range.lowerBound) / span
            ZStack(alignment: .leading) {
                track
                fill.frame(width: max(trackHeight, geo.size.width * fraction))
                if style != .glass {
                    thumbView.offset(x: min(max(geo.size.width * fraction - thumb / 2, 0), geo.size.width - thumb))
                }
            }
            .frame(height: geo.size.height)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let f = min(max(g.location.x / geo.size.width, 0), 1)
                value = range.lowerBound + f * span
            })
        }
        .frame(height: compact ? 14 : 24)
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

    @ViewBuilder private var track: some View {
        switch style {
        case .glass:
            Capsule().fill(Color.white.opacity(0.22)).frame(height: trackHeight)
        case .soft:
            Capsule().fill(PanelTheme.softBg).frame(height: trackHeight)
                .innerShadow(Capsule(), color: PanelTheme.softDark, radius: 3, x: 2, y: 2)
                .innerShadow(Capsule(), color: PanelTheme.softLight, radius: 3, x: -2, y: -2)
        case .leather:
            Capsule().fill(Color(red: 0.16, green: 0.08, blue: 0.03)).frame(height: trackHeight)
                .innerShadow(Capsule(), color: .black.opacity(0.8), radius: 2, x: 0, y: 2)
        }
    }

    @ViewBuilder private var fill: some View {
        switch style {
        case .glass:
            Capsule().fill(Color.white).frame(height: trackHeight)
        case .soft:
            Capsule().fill(LinearGradient(colors: [Color(red: 0.44, green: 0.61, blue: 1), PanelTheme.softAccent], startPoint: .leading, endPoint: .trailing))
                .frame(height: trackHeight - 4).padding(.leading, 2)
        case .leather:
            Capsule().fill(LinearGradient(colors: [PanelTheme.brass, Color(red: 0.79, green: 0.59, blue: 0.17)], startPoint: .top, endPoint: .bottom))
                .frame(height: trackHeight - 4).padding(.leading, 2)
                .shadow(color: PanelTheme.brass.opacity(0.5), radius: 4)
        }
    }

    @ViewBuilder private var thumbView: some View {
        switch style {
        case .soft:
            Circle().fill(PanelTheme.softBg).frame(width: thumb, height: thumb)
                .shadow(color: PanelTheme.softDark, radius: 4, x: 3, y: 3)
                .shadow(color: PanelTheme.softLight, radius: 4, x: -3, y: -3)
        default:
            Circle().fill(RadialGradient(colors: [.white, Color(white: 0.74), Color(white: 0.48)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: thumb))
                .frame(width: thumb, height: thumb)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 2)
        }
    }
}
