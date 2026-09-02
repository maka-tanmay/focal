import SwiftUI
import ServiceManagement

private let accent = Color(red: 0.55, green: 0.50, blue: 1.0)

struct PopoverView: View {
    @ObservedObject var overlay: Overlay
    let showTip: Bool
    @State private var login = SMAppService.mainApp.status == .enabled

    /// What the preview should show: 0 = nothing blurred.
    private var effectiveStrength: CGFloat {
        guard overlay.enabled else { return 0 }
        return overlay.auto ? 0.7 : overlay.strength
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            preview
            if showTip { tip }
            card { strengthSection }
            card { sharpSection }
            footer
        }
        .padding(18)
        .frame(width: 340)
        .animation(.easeInOut(duration: 0.3), value: effectiveStrength)
        .animation(.easeInOut(duration: 0.2), value: overlay.pinned)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(LinearGradient(colors: [accent, Color(red: 0.35, green: 0.25, blue: 0.9)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 38, height: 38)
            .shadow(color: accent.opacity(overlay.enabled ? 0.5 : 0), radius: 10, y: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text("Focal").font(.system(.title3, design: .rounded, weight: .bold))
                HStack(spacing: 5) {
                    Circle().fill(overlay.enabled ? Color.green : Color.secondary).frame(width: 6, height: 6)
                    Text(overlay.enabled ? "Active" : "Paused").font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Blur", isOn: $overlay.enabled.animation()).toggleStyle(.switch).labelsHidden().tint(accent)
        }
    }

    // MARK: - Live preview

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(white: 0.17), Color(white: 0.09)],
                                     startPoint: .top, endPoint: .bottom))
            miniWindow(width: 124, height: 78, tint: .orange)
                .offset(x: -74, y: -18)
                .blur(radius: effectiveStrength * 6)
                .opacity(1 - Double(effectiveStrength) * 0.45)
            miniWindow(width: 112, height: 72, tint: .teal)
                .offset(x: 78, y: 14)
                .blur(radius: effectiveStrength * 6)
                .opacity(1 - Double(effectiveStrength) * 0.45)
            miniWindow(width: 156, height: 94, tint: accent, front: true)
                .offset(y: 4)
                .shadow(color: .black.opacity(0.5), radius: 14, y: 8)
            VStack {
                Spacer()
                Text(overlay.enabled ? "Only your active window stays sharp" : "Paused. Everything is sharp.")
                    .font(.caption2).foregroundStyle(.white.opacity(0.55))
                    .padding(.bottom, 8)
            }
        }
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.08)))
    }

    private func miniWindow(width: CGFloat, height: CGFloat, tint: Color, front: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                ForEach(0..<3) { _ in Circle().fill(.white.opacity(0.35)).frame(width: 5, height: 5) }
            }
            RoundedRectangle(cornerRadius: 2).fill(tint.opacity(0.95)).frame(width: width * 0.45, height: 6)
            ForEach([0.8, 0.6, 0.7], id: \.self) { f in
                RoundedRectangle(cornerRadius: 2).fill(.white.opacity(0.22)).frame(width: width * f, height: 4)
            }
        }
        .padding(10)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(Color(white: front ? 0.24 : 0.19), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.white.opacity(front ? 0.3 : 0.1)))
    }

    // MARK: - Sections

    private var tip: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles").foregroundStyle(accent)
            Text("Click any window and everything behind it softens. Click ◐ in the menu bar to open this panel. ⌥-click it, or press ⌃⌥⌘F, to pause instantly.")
                .font(.caption).foregroundStyle(.primary.opacity(0.85))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(accent.opacity(0.25)))
    }

    private var strengthSection: some View {
        Group {
            HStack {
                Label("Blur strength", systemImage: "drop.fill").font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Auto", isOn: $overlay.auto.animation()).toggleStyle(.button).controlSize(.small).tint(accent)
            }
            HStack(spacing: 10) {
                Image(systemName: "circle").font(.caption2).foregroundStyle(.secondary)
                Slider(value: $overlay.strength, in: 0.2...1).tint(accent)
                Image(systemName: "circle.fill").font(.caption2).foregroundStyle(.secondary)
            }
            .disabled(overlay.auto)
            .opacity(overlay.auto ? 0.4 : 1)
            Text(overlay.auto
                 ? "Focal decides: stronger the more windows sit behind the active one, off when there's nothing to hide."
                 : "Drag to taste, or let Focal decide with Auto.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var sharpSection: some View {
        Group {
            Label("Also keep sharp", systemImage: "pin.fill").font(.subheadline.weight(.semibold))
            Text("Up to two extra windows stay clear beside the active one.")
                .font(.caption).foregroundStyle(.secondary)
            if !overlay.pinned.isEmpty {
                HStack(spacing: 6) {
                    ForEach(overlay.pinned, id: \.id) { ref in
                        HStack(spacing: 6) {
                            Text(ref.name).font(.caption.weight(.medium)).lineLimit(1)
                            Button { overlay.togglePin(ref) } label: {
                                Image(systemName: "xmark").font(.caption2.weight(.bold))
                            }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .help("Stop keeping this window sharp")
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent.opacity(0.22), in: Capsule())
                        .overlay(Capsule().strokeBorder(accent.opacity(0.35)))
                    }
                }
            }
            if let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 {
                Button { overlay.togglePin(ref) } label: {
                    Label("Keep “\(ref.name)” sharp", systemImage: "plus").font(.caption)
                }
                .buttonStyle(.bordered).controlSize(.small)
                .help("Pins the window you were just using")
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle("Launch at login", isOn: $login).toggleStyle(.checkbox).font(.caption).foregroundStyle(.secondary)
                .onChange(of: login) { on in
                    let service = SMAppService.mainApp
                    do {
                        if on { try service.register() } else { try service.unregister() }
                    } catch {
                        login = service.status == .enabled
                    }
                }
            Spacer()
            Text("⌃⌥⌘F")
                .font(.caption2.monospaced().weight(.semibold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.12)))
                .help("Global shortcut to pause or resume")
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.plain).font(.caption).foregroundStyle(.secondary)
                .padding(.leading, 6)
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8, content: content)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.07)))
    }
}
