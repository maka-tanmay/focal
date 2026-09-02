import SwiftUI
import ServiceManagement

// MARK: - Welcome

struct WelcomeTab: View {
    @ObservedObject var overlay: Overlay
    @ObservedObject var prefs: Prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HowItWorksView(icon: prefs.iconStyle)
            VStack(alignment: .leading, spacing: 14) {
                step(1, "Click any window", "Everything behind it softens. Focal follows you as you switch windows.")
                step(2, "Find Focal in the menu bar", "Click the icon for the quick panel: on/off, strength, and windows to keep sharp.")
                step(3, "Pause any time", "Press \(prefs.hotkey.label) or ⌥-click the icon. Same again to resume.")
            }
        }
        .padding(24)
        .frame(width: 560)
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.callout.weight(.semibold)).monospacedDigit()
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.accentColor.opacity(0.15)))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.semibold)
                Text(detail).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Animated mini desktop. A scripted loop: the cursor clicks each window in turn (it stays sharp, the rest
/// blur), then goes up to the menu bar icon and opens the quick panel. Stops under Reduce Motion.
struct HowItWorksView: View {
    let icon: IconStyle
    @State private var active = 0
    @State private var cursor = CGSize(width: -60, height: 70)
    @State private var pressed = false
    @State private var panelShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let apps: [(name: String, symbol: String, tint: Color)] = [
        ("Notes", "note.text", .yellow), ("Safari", "safari", .blue), ("Mail", "envelope.fill", .cyan),
    ]
    private let positions: [CGSize] = [CGSize(width: -130, height: 10), CGSize(width: 30, height: -18), CGSize(width: 150, height: 30)]
    private let iconOffset = CGSize(width: 150, height: -128)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(LinearGradient(colors: [Color(red: 0.42, green: 0.48, blue: 0.70), Color(red: 0.14, green: 0.16, blue: 0.28)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))

            // Windows
            ForEach(0..<3, id: \.self) { i in
                miniWindow(i)
                    .offset(positions[i])
                    .blur(radius: i == active ? 0 : 5)
                    .opacity(i == active ? 1 : 0.7)
                    .scaleEffect(i == active ? 1 : 0.97)
                    .zIndex(i == active ? 1 : 0)
                    .shadow(color: .black.opacity(i == active ? 0.4 : 0), radius: 16, y: 10)
            }

            // Menu bar
            VStack {
                HStack(spacing: 14) {
                    Spacer()
                    Image(nsImage: icon.image(on: true)).renderingMode(.template).resizable().frame(width: 16, height: 16)
                        .padding(3)
                        .background(Circle().fill(Color.accentColor.opacity(panelShown ? 0.9 : 0.35)))
                    Image(systemName: "wifi")
                    Image(systemName: "battery.75percent")
                    Text("9:41").monospacedDigit()
                }
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(height: 24)
                .background(.white.opacity(0.18))
                Spacer()
            }

            // Quick panel dropping from the icon
            if panelShown {
                miniPanel
                    .offset(x: 120, y: -70)
                    .transition(.opacity.combined(with: .offset(y: -8)))
                    .zIndex(3)
            }

            // Dock
            VStack {
                Spacer()
                HStack(spacing: 8) {
                    ForEach([Color.blue, .yellow, .cyan, .green, .purple], id: \.self) { c in
                        RoundedRectangle(cornerRadius: 5).fill(c.opacity(0.9)).frame(width: 18, height: 18)
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.2)))
                .padding(.bottom, 10)
            }

            // Cursor
            Image(systemName: "cursorarrow")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                .scaleEffect(pressed ? 0.8 : 1)
                .offset(cursor)
                .zIndex(4)

            // Caption
            VStack {
                Spacer()
                Text(panelShown ? "The quick panel: on/off, strength, pins" : "Only \(apps[active].name) stays sharp")
                    .font(.caption).foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Capsule().fill(.black.opacity(0.4)))
                    .padding(.bottom, 46)
            }
        }
        .frame(width: 512, height: 320)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .task { await play() }
        .accessibilityLabel("Three windows. The one you click stays sharp; the others blur. The menu bar icon opens the quick panel.")
    }

    private func play() async {
        guard !reduceMotion else { return }
        let sleep = { (s: Double) in try? await Task.sleep(nanoseconds: UInt64(s * 1_000_000_000)) }
        while !Task.isCancelled {
            for i in 0..<3 {
                withAnimation(.easeInOut(duration: 0.5)) {
                    cursor = CGSize(width: positions[i].width + 30, height: positions[i].height + 24)
                }
                await sleep(0.6)
                withAnimation(.easeOut(duration: 0.1)) { pressed = true }
                await sleep(0.12)
                withAnimation(.easeInOut(duration: 0.5)) { pressed = false; active = i }
                await sleep(1.5)
            }
            withAnimation(.easeInOut(duration: 0.6)) { cursor = CGSize(width: iconOffset.width, height: iconOffset.height + 10) }
            await sleep(0.7)
            withAnimation(.easeOut(duration: 0.1)) { pressed = true }
            await sleep(0.12)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { pressed = false; panelShown = true }
            await sleep(2.6)
            withAnimation(.easeIn(duration: 0.2)) { panelShown = false }
            await sleep(0.5)
        }
    }

    private var miniPanel: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(nsImage: icon.image(on: true)).renderingMode(.template).resizable().frame(width: 12, height: 12)
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(Color.accentColor))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Focal").font(.system(size: 9, weight: .semibold))
                    Text("On").font(.system(size: 7)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled").font(.system(size: 8)).foregroundStyle(.secondary)
                Capsule().fill(Color.primary.opacity(0.15)).frame(height: 4)
                    .overlay(alignment: .leading) { Capsule().fill(Color.accentColor).frame(width: 60, height: 4) }
                Text("80%").font(.system(size: 7)).foregroundStyle(.secondary)
            }
            .padding(6)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08)))
        }
        .padding(6)
        .frame(width: 130)
        .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.35)))
        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
    }

    private func miniWindow(_ i: Int) -> some View {
        let app = apps[i]
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                ForEach([Color.red, .yellow, .green], id: \.self) { c in Circle().fill(c).frame(width: 7, height: 7) }
                Spacer()
                Label(app.name, systemImage: app.symbol).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 8).frame(height: 22)
            .background(Color(nsColor: .windowBackgroundColor))
            Group {
                switch i {
                case 0: // Notes: a title and ruled lines
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 2).fill(app.tint.opacity(0.9)).frame(width: 70, height: 8)
                        ForEach([0.9, 0.75, 0.85, 0.6], id: \.self) { f in
                            RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.3)).frame(width: 150 * f, height: 5)
                        }
                    }
                case 1: // Safari: address bar and image blocks
                    VStack(alignment: .leading, spacing: 8) {
                        Capsule().fill(Color.secondary.opacity(0.2)).frame(height: 10)
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 4).fill(app.tint.opacity(0.6)).frame(height: 40)
                            RoundedRectangle(cornerRadius: 4).fill(app.tint.opacity(0.35)).frame(height: 40)
                        }
                        RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.3)).frame(width: 110, height: 5)
                    }
                default: // Mail: list rows
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(0..<4, id: \.self) { r in
                            HStack(spacing: 6) {
                                Circle().fill(r == 0 ? app.tint : Color.clear).frame(width: 5, height: 5)
                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(r == 0 ? 0.5 : 0.3)).frame(width: 60, height: 5)
                                RoundedRectangle(cornerRadius: 2).fill(Color.secondary.opacity(0.2)).frame(width: 70, height: 5)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .frame(width: 170, height: 96, alignment: .topLeading)
            .background(Color(nsColor: .textBackgroundColor))
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.black.opacity(0.15)))
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject var overlay: Overlay
    @State private var login = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Blur") {
                Toggle("Blur background", isOn: $overlay.enabled)
                LabeledContent("Strength") {
                    HStack {
                        Slider(value: $overlay.strength, in: 0.2...1).disabled(overlay.auto)
                        Text(overlay.auto ? "Auto" : "\(Int(overlay.strength * 100))%")
                            .foregroundStyle(.secondary).monospacedDigit().frame(width: 44, alignment: .trailing)
                    }
                }
                Toggle("Auto strength", isOn: $overlay.auto)
                caption("Stronger when more windows sit behind the active one. Off when there is nothing to hide.")
            }
            Section("Full screen") {
                Toggle("Skip full-screen apps", isOn: $overlay.skipFullScreen)
                caption("Swiping to a full-screen app never blurs it. Turn off to blur inside Split View.")
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $login)
                    .onChange(of: login) { on in
                        let service = SMAppService.mainApp
                        do {
                            if on { try service.register() } else { try service.unregister() }
                        } catch {
                            login = service.status == .enabled
                        }
                    }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 360)
    }
}

// MARK: - Icon

struct IconTab: View {
    @ObservedObject var prefs: Prefs
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick how Focal looks in the menu bar. Each card shows the blurring and paused states on a light and a dark menu bar.")
                .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(IconStyle.allCases) { style in
                    IconCard(style: style, selected: style == prefs.iconStyle) { prefs.iconStyle = style }
                }
            }
        }
        .padding(24)
        .frame(width: 560)
    }
}

struct IconCard: View {
    let style: IconStyle
    let selected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            VStack(spacing: 8) {
                HStack(spacing: 0) {
                    strip(dark: false)
                    strip(dark: true)
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(style.title).font(.callout)
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(selected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03)))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func strip(dark: Bool) -> some View {
        HStack(spacing: 14) {
            glyph(on: true, dark: dark)
            glyph(on: false, dark: dark)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(dark ? Color(white: 0.16) : Color(white: 0.93))
    }

    private func glyph(on: Bool, dark: Bool) -> some View {
        Image(nsImage: style.image(on: on))
            .renderingMode(.template)
            .resizable().interpolation(.high)
            .frame(width: 26, height: 26)
            .foregroundStyle(dark ? .white : .black)
    }
}

// MARK: - Shortcuts

struct ShortcutsTab: View {
    @ObservedObject var prefs: Prefs

    var body: some View {
        Form {
            Section {
                LabeledContent("Pause or resume Focal") { ShortcutRecorder(hotkey: $prefs.hotkey) }
                caption("Works in any app. Click Change…, then press the keys you want. The combo needs ⌘, ⌥ or ⌃.")
            } header: {
                Text("Keyboard")
            }
            Section("Mouse") {
                LabeledContent("Open the quick panel") { Text("Click the menu bar icon").foregroundStyle(.secondary) }
                LabeledContent("Pause or resume") {
                    HStack(spacing: 6) { Keycaps(label: "⌥"); Text("+ click the icon").foregroundStyle(.secondary) }
                }
                LabeledContent("Close the panel") { Keycaps(label: "⎋") }
            }
        }
        .formStyle(.grouped)
        .frame(width: 560, height: 300)
    }
}

// MARK: - About

struct AboutTab: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 96, height: 96)
            VStack(spacing: 4) {
                Text("Focal").font(.title.weight(.semibold))
                Text("Version \(version)").foregroundStyle(.secondary)
            }
            Text("Blur everything except the window you're working in.")
            HStack(spacing: 16) {
                Link("GitHub", destination: URL(string: "https://github.com/maka-tanmay/focal")!)
                Link("Report a problem", destination: URL(string: "https://github.com/maka-tanmay/focal/issues")!)
            }
            Text("Free and open source under the MIT license. No account, no tracking, no permissions. Inspired by Monocle.")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(32)
        .frame(width: 560)
    }
}

private func caption(_ text: String) -> some View {
    Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}
