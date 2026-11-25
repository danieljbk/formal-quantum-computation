import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @EnvironmentObject private var settings: AppSettingsStore
    @ObservedObject private var systemAlarms = SystemAlarmService.shared
    @State private var permissionRows: [PermissionRow] = []
    private let manifest = SoundManifest.load(from: .main)
    private let sleepManifest = SoundManifest.load(from: .main, named: "sleep_sounds")

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $settings.prefs.theme) {
                        ForEach(AppTheme.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    NavigationLink {
                        VoiceGalleryView()
                    } label: {
                        LabeledContent("Baby voices", value: BabyVoiceCatalog.displayName(for: engine.defaultVoiceID))
                    }
                    NavigationLink {
                        DefaultMissionsView()
                    } label: {
                        LabeledContent("Default missions", value: settings.prefs.defaultMissions.isEmpty
                                       ? "None" : settings.prefs.defaultMissions.map(\.kind.title).joined(separator: " → "))
                    }
                    LabeledContent("Backup sound", value: "System alert tone")
                } header: {
                    Text("New alarms")
                } footer: {
                    Text("If a baby clip can't be played, the app falls back to the default baby, then to the system alert tone, so an alarm is never silent.")
                }

                Section {
                    Toggle("Briefing after the alarm", isOn: $settings.prefs.showBriefingAfterAlarm)
                    Toggle("Local weather", isOn: $settings.prefs.briefingWeather)
                    Picker("Fortune sign", selection: $settings.prefs.zodiac) {
                        ForEach(Zodiac.allCases) { Text("\($0.symbol) \($0.title)").tag($0) }
                    }
                } header: {
                    Text("Morning briefing")
                }

                Section {
                    LabeledContent("System alarm (AlarmKit)", value: systemAlarmText)
                    if systemAlarms.status == .notDetermined {
                        Button("Allow system alarms") { systemAlarms.requestAuthorization() }
                    }
                    Toggle("Keep ringing from the background", isOn: $engine.keepAliveEnabled)
                } header: {
                    Text("Ringing")
                } footer: {
                    Text("On iOS 26 and later, alarms are also registered as system alarms: they ring through Silent mode and Focus even if the app was closed, and “Calm the baby” opens your missions. On every iOS version the app also keeps a silent audio stream running in the background so the crying plays at full length, and repeats 30-second notification cries until you open it.")
                }

                Section {
                    ForEach(permissionRows) { row in
                        HStack(spacing: 12) {
                            Image(systemName: row.symbol).frame(width: 26).foregroundColor(Theme.lilac)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.title)
                                Text(row.detail).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(stateText(row.state))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(stateColor(row.state))
                        }
                    }
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iOS Settings", destination: url)
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Each permission is asked for the first time a feature needs it.")
                }

                creditsSection(title: "Baby voices", manifest: manifest) { id in
                    BabyVoiceCatalog.voice(id: id).map { "\($0.emoji) \($0.displayName)" }
                }
                creditsSection(title: "Sleep sounds", manifest: sleepManifest) { id in
                    SleepSoundCatalog.sound(id: id).map { "\($0.emoji) \($0.displayName)" }
                }

                Section("About") {
                    Text("Every alarm and sleep sound is a real recording from Wikimedia Commons (CC0, public domain or CC BY-SA 4.0). The CC BY-SA clip was trimmed and loudness-normalised, and the converted clip is shared under the same licence. Weather data by Open-Meteo.com.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear(perform: refreshPermissions)
        }
    }

    private var systemAlarmText: String {
        switch systemAlarms.status {
        case .authorized: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not asked"
        case .unsupported: return "Needs iOS 26"
        }
    }

    private func refreshPermissions() {
        SystemAlarmService.shared.refreshStatus()
        engine.refreshNotificationStatus()
        UNUserNotificationCenter.current().getNotificationSettings { s in
            let status = s.authorizationStatus
            DispatchQueue.main.async { permissionRows = PermissionCenter.rows(notifications: status) }
        }
    }

    private func stateText(_ state: PermissionRow.State) -> String {
        switch state {
        case .granted: return "Allowed"
        case .denied: return "Off"
        case .notAsked: return "Not asked"
        case .unavailable: return "Unavailable"
        }
    }

    private func stateColor(_ state: PermissionRow.State) -> Color {
        switch state {
        case .granted: return .green
        case .denied: return .orange
        case .notAsked, .unavailable: return .secondary
        }
    }

    @ViewBuilder
    private func creditsSection(title: String, manifest: SoundManifest?, name: @escaping (String) -> String?) -> some View {
        Section(title + " – credits") {
            ForEach(manifest?.sounds ?? []) { s in
                VStack(alignment: .leading, spacing: 4) {
                    Text(name(s.id) ?? s.id).font(.headline)
                    Text("“\(s.title)” by \(s.author)").font(.subheadline)
                    Text(s.license).font(.caption).foregroundColor(.secondary)
                    if let url = URL(string: s.sourcePage) {
                        Link("Source", destination: url).font(.caption)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

/// Missions that new alarms start with.
struct DefaultMissionsView: View {
    @EnvironmentObject private var settings: AppSettingsStore

    var body: some View {
        Form {
            Section {
                ForEach($settings.prefs.defaultMissions) { $mission in
                    NavigationLink {
                        MissionEditorView(mission: $mission)
                    } label: {
                        Label(mission.summary, systemImage: mission.kind.symbolName)
                    }
                }
                .onDelete { settings.prefs.defaultMissions.remove(atOffsets: $0) }
                if settings.prefs.defaultMissions.count < Alarm.maxMissions {
                    Menu {
                        ForEach(MissionKind.selectable.filter { !$0.needsRegistration }) { kind in
                            Button { settings.prefs.defaultMissions.append(MissionSettings(kind: kind)) } label: {
                                Label(kind.title, systemImage: kind.symbolName)
                            }
                        }
                    } label: {
                        Label("Add mission", systemImage: "plus.circle.fill")
                    }
                }
            } footer: {
                Text("Photo and barcode missions are set up per alarm, because each needs its own registered spot or code.")
            }
        }
        .navigationTitle("Default missions")
    }
}
