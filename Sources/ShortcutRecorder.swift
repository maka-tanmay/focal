import SwiftUI

/// Click, press a key combo, done. Escape cancels. Needs ⌘, ⌥ or ⌃ so it can't swallow plain typing.
struct ShortcutRecorder: View {
    @Binding var hotkey: Hotkey
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(recording ? "Press keys…" : hotkey.label) { recording ? stop() : start() }
                .frame(minWidth: 110)
                .foregroundStyle(recording ? .secondary : .primary)
            Button("Reset") { hotkey = .standard }
                .disabled(hotkey == .standard)
        }
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
