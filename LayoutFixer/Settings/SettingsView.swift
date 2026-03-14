import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @Environment(AppSettings.self) var settings
    @Environment(AppDelegate.self) var appDelegate

    @State private var axGranted = false
    @State private var tapActive = false

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section("Permissions") {
                permissionRow(
                    ok: axGranted,
                    label: "Accessibility",
                    detail: "Required to read and replace text",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                permissionRow(
                    ok: tapActive,
                    label: "Input Monitoring",
                    detail: axGranted ? "Required to detect the hotkey" : "Grant Accessibility first",
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                )
            }
            Section("Hotkey") {
                HotkeyRecorder(hotkey: $settings.hotkey)
            }
            Section("Sound") {
                Picker("Sound", selection: $settings.soundName) {
                    ForEach(SoundPlayer.availableSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                Slider(value: $settings.soundVolume, in: 0...1) {
                    Text("Volume")
                }
                Toggle("Enable sound", isOn: $settings.soundEnabled)
                Button("Preview") {
                    SoundPlayer().play(name: settings.soundName, volume: settings.soundVolume)
                }
            }
            Section("General") {
                Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        LoginItemManager.shared.setEnabled(newValue)
                    }
            }
            Section("Language Cycle") {
                LanguageOrderView()
            }
            Section("Advanced") {
                HStack {
                    Text("Clipboard timeout")
                    Spacer()
                    TextField("ms", value: $settings.clipboardPollTimeoutMs, format: .number)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 64)
                    Text("ms")
                        .foregroundStyle(.secondary)
                }
                .help("How long to wait for ⌘C to update the clipboard. Raise this if text replacement is unreliable.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .task {
            refreshPermissions()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            refreshPermissions()
        }
    }

    private func refreshPermissions() {
        let opts: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): false]
        axGranted = AXIsProcessTrustedWithOptions(opts)
        tapActive = appDelegate.hotkeyManager?.isEventTapActive ?? false
    }

    @ViewBuilder
    private func permissionRow(ok: Bool, label: String, detail: String, settingsURL: String) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? .green : .red)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !ok, let url = URL(string: settingsURL) {
                Button("Open Settings") { NSWorkspace.shared.open(url) }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.blue)
            }
        }
    }
}
