import SwiftUI

/// Lists the recorded baby voices with previews. With a `selection` binding it's a picker,
/// without one it's the browsable "Voices" tab (with credits).
struct VoicePickerView: View {
    @EnvironmentObject private var player: CryPlayer
    var selection: Binding<String>?

    var body: some View {
        List {
            Section {
                ForEach(BabyVoice.catalog) { voice in
                    VoiceRow(voice: voice,
                             isSelected: selection?.wrappedValue == voice.id,
                             isPlaying: player.previewingVoiceID == voice.id,
                             onPlay: { player.togglePreview(voice) },
                             onSelect: selection.map { binding -> () -> Void in { binding.wrappedValue = voice.id } })
                }
            } footer: {
                Text("Every voice is a real recording of a crying baby, used under the license shown.")
            }

            if selection == nil {
                Section("Credits") {
                    ForEach(BabyVoice.catalog) { voice in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.creditLine).font(.footnote)
                            if let url = URL(string: voice.sourcePage) {
                                Link(voice.sourcePage, destination: url)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(selection == nil ? "Baby voices" : "Choose a baby")
        .onDisappear { player.stopPreview() }
    }
}

struct VoiceRow: View {
    let voice: BabyVoice
    let isSelected: Bool
    let isPlaying: Bool
    let onPlay: () -> Void
    let onSelect: (() -> Void)?

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying ? "Stop \(voice.name)" : "Play \(voice.name)")

            VStack(alignment: .leading, spacing: 2) {
                Text(voice.name).font(.headline)
                Text(voice.subtitle).font(.subheadline).foregroundStyle(.secondary)
                Text("\(voice.author) \u{00B7} \(voice.license)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark").foregroundStyle(Theme.accent).fontWeight(.bold)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect?() }
        .padding(.vertical, 4)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
