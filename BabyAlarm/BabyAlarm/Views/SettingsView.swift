import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @Environment(\.dismiss) private var dismiss
    private let manifest = SoundManifest.load(from: .main)

    private var notificationText: String {
        switch engine.notificationStatus {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Keep ringing from the background", isOn: $engine.keepAliveEnabled)
                } header: {
                    Text("Ringing")
                } footer: {
                    Text("While an alarm is set, the app keeps a silent audio stream running in the background so the crying can play at full length. Without it, iOS limits each notification sound to 30 seconds and the app repeats them until you open it. Force-quitting the app turns this off until you open it again.")
                }

                Section("Notifications") {
                    LabeledContent("Alarm notifications", value: notificationText)
                    if engine.notificationStatus == .denied,
                       let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open iOS Settings", destination: url)
                    }
                }

                Section {
                    ForEach(manifest?.sounds ?? []) { s in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(BabyVoiceCatalog.voice(id: s.id)?.emoji ?? "👶") \(BabyVoiceCatalog.voice(id: s.id)?.displayName ?? s.id)")
                                .font(.headline)
                            Text("“\(s.title)” by \(s.author)")
                                .font(.subheadline)
                            Text(s.license)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let url = URL(string: s.sourcePage) {
                                Link("Source", destination: url).font(.caption)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Baby voices & credits")
                } footer: {
                    Text("Real recordings from Wikimedia Commons, used under their CC0, public-domain or CC BY-SA 4.0 licences. The CC BY-SA clip was converted (trimmed, loudness-normalised); the converted clip is shared under the same licence.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
