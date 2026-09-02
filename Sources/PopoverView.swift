import SwiftUI
import ServiceManagement

/// The menu bar panel. Native controls on the popover's own material, grouped by hairlines.
struct PopoverView: View {
    @ObservedObject var overlay: Overlay
    let showTip: Bool
    @State private var login = SMAppService.mainApp.status == .enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if showTip { tip }
            Divider()
            strength
            Divider()
            keepSharp
            Divider()
            fullScreen
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 300)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Focal").font(.headline)
                Text(overlay.enabled ? "Blurring everything behind your active window" : "Paused. Nothing is blurred.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("Blur background", isOn: $overlay.enabled)
                .toggleStyle(.switch).labelsHidden()
        }
    }

    private var tip: some View {
        Text("Click any window and everything behind it softens. Click ◐ in the menu bar to open this panel. ⌥-click it, or press ⌃⌥⌘F, to pause.")
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Strength

    private var strength: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Strength").fontWeight(.semibold)
                Spacer()
                Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                    .foregroundStyle(.secondary).monospacedDigit()
            }
            Slider(value: $overlay.strength, in: 0.2...1)
                .disabled(overlay.auto)
                .opacity(overlay.auto ? 0.4 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: overlay.auto)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Auto")
                    Text("Stronger when more windows are behind. Off when there is nothing to hide.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Toggle("Auto strength", isOn: $overlay.auto)
                    .toggleStyle(.switch).labelsHidden().controlSize(.small)
            }
        }
    }

    // MARK: - Keep sharp

    private var keepSharp: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keep sharp").fontWeight(.semibold)
                Spacer()
                Text("\(overlay.pinned.count) of 2").foregroundStyle(.secondary).monospacedDigit()
            }
            Text("Windows that stay clear next to the active one.")
                .font(.caption).foregroundStyle(.secondary)

            ForEach(overlay.pinned, id: \.id) { ref in
                windowRow(ref, hint: nil) {
                    Button("Unpin") { pin(ref) }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .transition(.opacity)
            }

            if let ref = overlay.active, !overlay.pinned.contains(ref), overlay.pinned.count < 2 {
                windowRow(ref, hint: "the window you were just using") {
                    Button("Pin") { pin(ref) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                }
                .transition(.opacity)
            } else if overlay.pinned.isEmpty {
                Text("Open this panel while a window is in front to pin it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func windowRow<Action: View>(_ ref: WindowRef, hint: String?, @ViewBuilder action: () -> Action) -> some View {
        HStack(spacing: 8) {
            Image(nsImage: ref.icon).resizable().frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(ref.name).lineLimit(1)
                if let hint { Text(hint).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            action()
        }
        .frame(minHeight: 28)
    }

    private func pin(_ ref: WindowRef) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { overlay.togglePin(ref) }
    }

    private var fullScreen: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Skip full-screen apps")
                Text("Swiping to a full-screen app never blurs it.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Toggle("Skip full-screen apps", isOn: $overlay.skipFullScreen)
                .toggleStyle(.switch).labelsHidden().controlSize(.small)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Toggle("Launch at login", isOn: $login)
                .toggleStyle(.checkbox).font(.caption)
                .onChange(of: login) { on in
                    let service = SMAppService.mainApp
                    do {
                        if on { try service.register() } else { try service.unregister() }
                    } catch {
                        login = service.status == .enabled
                    }
                }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Text("⌃⌥⌘F")
                    .font(.caption.monospaced())
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                Text(overlay.enabled ? "pauses" : "resumes").font(.caption).foregroundStyle(.secondary)
            }
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless).font(.caption)
        }
    }
}
