import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppModel.self) private var model

    private func setting<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { model.settings[keyPath: keyPath] },
                set: { value in model.updateSettings { $0[keyPath: keyPath] = value } })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if model.alarmKitSupported {
                        permissionRow("System alarms", granted: model.alarmKitAuthorized,
                                      detail: "Rings through Silent mode and Focus, even if the app is closed.") {
                            Task { await model.requestAlarmKitAccess() }
                        }
                    }
                    permissionRow("Notifications", granted: model.notificationsAuthorized,
                                  detail: model.alarmKitAuthorized
                                      ? "Used for wake-up checks and bedtime reminders."
                                      : "Rings the crying baby if the app isn't running.") {
                        Task { await model.requestNotificationAccess() }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    if !model.alarmKitAuthorized {
                        Text("Without system alarms, keep CradleCall open in the background (don't swipe it away) "
                             + "so the baby can cry at full volume.")
                    }
                }

                Section {
                    Toggle("Lock volume while ringing", isOn: setting(\.antiCheat.lockVolume))
                    Picker("Restart idle mission after", selection: setting(\.antiCheat.inactivityResetSeconds)) {
                        ForEach([10, 15, 20, 30, 45, 60], id: \.self) { Text("\($0) s").tag($0) }
                    }
                    Stepper("Backup rings: \(model.settings.antiCheat.backupRingCount)",
                            value: setting(\.antiCheat.backupRingCount), in: 3...30)
                    Toggle("Keep alive in background", isOn: setting(\.antiCheat.keepAliveInBackground))
                    Stepper("Emergency phrase ×\(model.settings.antiCheat.emergencyPhraseRepeats)",
                            value: setting(\.antiCheat.emergencyPhraseRepeats), in: 1...10)
                    Toggle("New alarms need a mission", isOn: setting(\.antiCheat.requireMission))
                } header: {
                    Text("No going back to sleep")
                } footer: {
                    Text("Stopping a system alarm without finishing the mission makes the baby cry again a "
                         + "minute later. Force-quitting the app mid-mission does too.")
                }

                Section("Morning briefing") {
                    Toggle("Weather (uses location)", isOn: setting(\.briefingUsesLocation))
                    Toggle("Today's calendar", isOn: setting(\.briefingUsesCalendar))
                    Picker("Temperature", selection: setting(\.useCelsius)) {
                        Text("Celsius").tag(true)
                        Text("Fahrenheit").tag(false)
                    }
                }

                Section {
                    NavigationLink("Credits & licences") { CreditsView() }
                    Button("Open iOS Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }

    private func permissionRow(_ title: String, granted: Bool, detail: String,
                               request: @escaping () -> Void) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    .accessibilityLabel("Allowed")
            } else {
                Button("Allow", action: request).buttonStyle(.bordered)
            }
        }
    }
}

struct CreditsView: View {
    var body: some View {
        List {
            Section {
                Text("Every bundled alarm voice is a genuine recording of a crying infant from the "
                     + "Donate-a-cry corpus (github.com/gveres/donateacry-corpus), recorded by parents "
                     + "with the Donate-a-cry app.")
                Text("The corpus is made available under the Open Database License (ODbL) v1.0; individual "
                     + "recordings are licensed under the Database Contents License (DbCL) v1.0. "
                     + "The clips were trimmed, joined and loudness-normalised for use as alarm sounds.")
            } header: {
                Text("Baby voices")
            }
            Section("Voices") {
                ForEach(BabyVoice.bundled) { voice in
                    LabeledContent(voice.name, value: voice.detail)
                }
            }
            Section("Weather") {
                Text("Weather data by Open-Meteo.com (CC BY 4.0).")
            }
        }
        .navigationTitle("Credits")
    }
}
