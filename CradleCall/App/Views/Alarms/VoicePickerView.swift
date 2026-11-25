import SwiftUI
import UniformTypeIdentifiers

struct VoicePickerView: View {
    @Environment(AppModel.self) private var model
    @Binding var selection: String
    @StateObject private var preview = VoicePreviewPlayer()
    @State private var recording = false
    @State private var importing = false
    @State private var importError: String?

    var body: some View {
        List {
            Section {
                ForEach(BabyVoice.bundled) { voice in
                    row(voice)
                }
            } header: {
                Text("Real baby recordings")
            } footer: {
                Text("Recorded by parents for the Donate-a-cry project. See Settings › Credits.")
            }

            Section("Your recordings") {
                ForEach(model.customVoices) { voice in
                    row(voice)
                        .swipeActions {
                            Button(role: .destructive) {
                                if selection == voice.id { selection = BabyVoice.defaultID }
                                model.deleteCustomVoice(voice)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                }
                Button { recording = true } label: {
                    Label("Record your baby", systemImage: "mic.circle.fill")
                }
                Button { importing = true } label: {
                    Label("Import a recording", systemImage: "square.and.arrow.down")
                }
                if let importError {
                    Text(importError).font(.footnote).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Baby voice")
        .onDisappear { preview.stop() }
        .sheet(isPresented: $recording) {
            VoiceRecorderView { voice in
                model.addCustomVoice(voice)
                selection = voice.id
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    let name = url.deletingPathExtension().lastPathComponent
                    let voice = try VoiceLibrary.importAudio(from: url, name: name)
                    model.addCustomVoice(voice)
                    selection = voice.id
                    importError = nil
                } catch {
                    importError = "Couldn't import that file: \(error.localizedDescription)"
                }
            case .failure(let error):
                importError = error.localizedDescription
            }
        }
    }

    private func row(_ voice: BabyVoice) -> some View {
        HStack {
            Button { preview.toggle(voice) } label: {
                Image(systemName: preview.playingID == voice.id ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accent)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(preview.playingID == voice.id ? "Stop preview" : "Play preview")
            VStack(alignment: .leading) {
                Text(voice.name)
                Text(voice.detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if selection == voice.id {
                Image(systemName: "checkmark").foregroundStyle(Theme.accent).bold()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = voice.id }
    }
}

struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var recorder = VoiceRecorder()
    @State private var name = "My baby"
    let onSave: (BabyVoice) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Text("Hold the phone near your baby while they cry. Recordings stop after "
                     + "\(Int(BabyVoice.maximumNotificationSeconds)) seconds so iOS can use them as an alarm.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 180 + CGFloat(recorder.level) * 80,
                               height: 180 + CGFloat(recorder.level) * 80)
                        .animation(.easeOut(duration: 0.1), value: recorder.level)
                    Button {
                        recorder.isRecording ? recorder.stop() : recorder.start()
                    } label: {
                        Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                            .frame(width: 150, height: 150)
                            .background(Theme.accent, in: Circle())
                    }
                    .accessibilityLabel(recorder.isRecording ? "Stop recording" : "Start recording")
                }
                .frame(height: 280)

                Text(String(format: "%.1f s", recorder.elapsed))
                    .font(.title.monospacedDigit())

                if recorder.recordedURL != nil {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                }
                if let error = recorder.errorMessage {
                    Text(error).foregroundStyle(.red).font(.footnote)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Record a cry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.stop()
                        recorder.discard()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let url = recorder.recordedURL else { return }
                        onSave(BabyVoice(id: "custom-\(UUID().uuidString)",
                                         name: name.isEmpty ? "My baby" : name,
                                         detail: "Recorded \(Date().formatted(date: .abbreviated, time: .omitted))",
                                         origin: .recorded, fileName: url.lastPathComponent))
                        dismiss()
                    }
                    .disabled(recorder.recordedURL == nil)
                }
            }
        }
    }
}
