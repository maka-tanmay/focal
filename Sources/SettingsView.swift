import SwiftUI
import ServiceManagement

/// The Settings window: welcome, every option, About. Opens on first launch and from the dropdown.
struct SettingsView: View {
    @ObservedObject var overlay: Overlay
    @ObservedObject var prefs: Prefs
    @State private var login = SMAppService.mainApp.status == .enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Focal").font(.title2.weight(.semibold))
                        Text("Blur everything except the window you're working in.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
                Label("Click any window. Everything behind it softens.", systemImage: "macwindow.on.rectangle")
                Label("Click the ◐ icon in the menu bar for the quick panel.", systemImage: "menubar.rectangle")
                Label("\(prefs.hotkey.label) pauses or resumes from anywhere. ⌥-clicking the icon does the same.", systemImage: "keyboard")
            }

            Section("Blur") {
                Toggle("Blur background", isOn: $overlay.enabled)
                Slider(value: $overlay.strength, in: 0.2...1) { Text("Strength") }
                    .disabled(overlay.auto)
                Toggle("Auto strength", isOn: $overlay.auto)
                caption("Stronger when more windows sit behind the active one. Off when there is nothing to hide.")
                Toggle("Skip full-screen apps", isOn: $overlay.skipFullScreen)
                caption("Swiping to a full-screen app never blurs it. Turn off to blur inside Split View.")
            }

            Section("Keep sharp") {
                caption("Up to two windows stay clear next to the active one. Pin from the quick panel while the window you want is in front.")
                ForEach(overlay.pinned, id: \.id) { ref in
                    HStack {
                        Image(nsImage: ref.icon).resizable().frame(width: 20, height: 20)
                        Text(ref.name)
                        Spacer()
                        Button("Unpin") { overlay.togglePin(ref) }.controlSize(.small)
                    }
                }
                if overlay.pinned.isEmpty {
                    Text("No pinned windows").foregroundStyle(.tertiary)
                }
            }

            Section("Menu bar icon") {
                Picker("Style", selection: $prefs.iconStyle) {
                    ForEach(IconStyle.allCases) { style in
                        HStack(spacing: 6) {
                            Image(nsImage: style.image(on: true))
                            Image(nsImage: style.image(on: false))
                            Text(style.title)
                        }
                        .tag(style)
                    }
                }
                .pickerStyle(.radioGroup)
                caption("Left is blurring, right is paused.")
            }

            Section("Shortcut") {
                LabeledContent("Pause or resume") { ShortcutRecorder(hotkey: $prefs.hotkey) }
                caption("Click the shortcut, then press the keys you want. Escape cancels.")
            }

            Section("General") {
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

            Section("About") {
                LabeledContent("Version", value: version)
                Link("Source code on GitHub", destination: URL(string: "https://github.com/maka-tanmay/focal")!)
                caption("Free and open source, MIT licensed. No account, no tracking, no permissions.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 500, height: 720)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
}
