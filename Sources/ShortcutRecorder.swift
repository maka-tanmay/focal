import SwiftUI

/// Shows the shortcut as keycaps. "Change…" starts recording: press a combo, Escape cancels.
/// A combo must include ⌘, ⌥ or ⌃ so plain typing can't be captured.
struct ShortcutRecorder: View {
    @Binding var hotkey: Hotkey
    @State private var recording = false
    @State private var monitor: Any?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 12) {
            if recording {
                Text("Type a shortcut…")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(Color.accentColor, lineWidth: 2))
                Button("Cancel", action: stop).controlSize(.small)
            } else {
                Keycaps(label: hotkey.label)
                Button("Change…", action: start).controlSize(.small)
                if hotkey != .standard {
                    Button("Reset") { hotkey = .standard }.controlSize(.small)
                }
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: recording)
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }          // Escape cancels
            guard let new = Hotkey(event: event) else { return nil } // wait for a real modifier
            hotkey = new
            stop()
            return nil
        }
    }

    private func stop() {
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}

/// "⌃⌥⌘F" → [⌃] [⌥] [⌘] [F] drawn as keycaps.
struct Keycaps: View {
    let label: String

    private var keys: [String] {
        var out: [String] = []
        var rest = label
        while let first = rest.first, "⌃⌥⇧⌘".contains(first) {
            out.append(String(first))
            rest.removeFirst()
        }
        if !rest.isEmpty { out.append(rest) }
        return out
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(keys.enumerated()), id: \.offset) { _, key in
                Text(key)
                    .font(.system(.body, design: .rounded).weight(.medium))
                    .frame(minWidth: 26)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .controlBackgroundColor))
                            .shadow(color: .black.opacity(0.25), radius: 0.5, y: 1)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.primary.opacity(0.15)))
            }
        }
    }
}
