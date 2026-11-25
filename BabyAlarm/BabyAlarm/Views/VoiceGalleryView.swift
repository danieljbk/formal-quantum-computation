import SwiftUI

/// "Babies" tab: listen to every crying voice, pick the default for new
/// alarms, or switch every alarm to one baby at once.
struct VoiceGalleryView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @State private var playing: String?
    @State private var confirmApply: String?
    private let manifest = SoundManifest.load(from: .main)

    var body: some View {
            List {
                Section {
                    ForEach(BabyVoiceCatalog.all) { voice in
                        VoiceCard(voice: voice,
                                  source: manifest?.source(for: voice.id),
                                  isDefault: engine.defaultVoiceID == voice.id,
                                  isPlaying: playing == voice.id,
                                  onPlay: { togglePreview(voice) },
                                  onMakeDefault: { engine.defaultVoiceID = voice.id },
                                  onApplyAll: { confirmApply = voice.id })
                    }
                } header: {
                    Text("Who's waking you up?")
                } footer: {
                    Text("The default baby is pre-selected for new alarms and quick alarms.")
                }

                Section {
                    Button {
                        engine.defaultVoiceID = BabyVoiceCatalog.randomID
                    } label: {
                        HStack {
                            Text("🎲 Surprise baby by default")
                            Spacer()
                            if engine.defaultVoiceID == BabyVoiceCatalog.randomID {
                                Image(systemName: "checkmark").foregroundColor(Theme.lilac)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                } footer: {
                    Text("A different baby cries every morning.")
                }
            }
            .navigationTitle("Baby voices")
            .onDisappear {
                AudioService.shared.stopPreview()
                playing = nil
            }
            .confirmationDialog("Use this baby for every alarm?",
                                isPresented: Binding(get: { confirmApply != nil },
                                                     set: { if !$0 { confirmApply = nil } }),
                                titleVisibility: .visible) {
                Button("Use for all alarms") {
                    if let id = confirmApply { engine.applyVoiceToAllAlarms(id) }
                    confirmApply = nil
                }
                Button("Cancel", role: .cancel) { confirmApply = nil }
            }
    }

    private func togglePreview(_ voice: BabyVoice) {
        if playing == voice.id {
            AudioService.shared.stopPreview()
            playing = nil
            return
        }
        let duration = AudioService.shared.preview(voice)
        guard duration > 0 else { return }
        playing = voice.id
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if playing == voice.id { playing = nil }
        }
    }
}

private struct VoiceCard: View {
    let voice: BabyVoice
    let source: SoundSource?
    let isDefault: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onMakeDefault: () -> Void
    let onApplyAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text(voice.emoji)
                    .font(.system(size: 40))
                    .frame(width: 60, height: 60)
                    .background(Theme.pink.opacity(isPlaying ? 0.45 : 0.18))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(voice.displayName).font(.headline)
                        if isDefault {
                            Text("Default")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Theme.lilac.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                    Text(voice.blurb).font(.caption).foregroundColor(.secondary)
                    if let source {
                        Text("\(source.author) · \(source.license)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Button(action: onPlay) {
                    Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 34))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(isPlaying ? "Stop \(voice.displayName)" : "Play \(voice.displayName)")
            }
            HStack {
                Button("Make default", action: onMakeDefault)
                    .disabled(isDefault)
                Button("Use for all alarms", action: onApplyAll)
            }
            .buttonStyle(.bordered)
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
}
