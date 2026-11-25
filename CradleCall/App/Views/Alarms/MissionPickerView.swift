import SwiftUI

/// Choose which kind of mission to add.
struct MissionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var configuring: MissionConfig?
    let onAdd: (MissionConfig) -> Void

    var body: some View {
        NavigationStack {
            List(MissionKind.allCases) { kind in
                Button { configuring = MissionConfig(kind: kind) } label: {
                    HStack(spacing: 14) {
                        Image(systemName: kind.symbol)
                            .font(.title2)
                            .frame(width: 36)
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text(kind.title).foregroundStyle(.primary)
                            Text(kind.summary).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add mission")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .navigationDestination(item: $configuring) { mission in
                MissionConfigForm(mission: mission) { configured in
                    onAdd(configured)
                    dismiss()
                }
            }
        }
    }
}

/// Edit an existing mission in a sheet.
struct MissionConfigView: View {
    @Environment(\.dismiss) private var dismiss
    let mission: MissionConfig
    let onSave: (MissionConfig) -> Void

    var body: some View {
        NavigationStack {
            MissionConfigForm(mission: mission) { updated in
                onSave(updated)
                dismiss()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
        }
    }
}

struct MissionConfigForm: View {
    @State private var mission: MissionConfig
    @State private var scanning = false
    @State private var trying = false
    let onDone: (MissionConfig) -> Void

    init(mission: MissionConfig, onDone: @escaping (MissionConfig) -> Void) {
        _mission = State(initialValue: mission)
        self.onDone = onDone
    }

    var body: some View {
        Form {
            Section {
                Label(mission.kind.summary, systemImage: mission.kind.symbol)
            }
            if mission.kind == .barcode {
                Section {
                    Button { scanning = true } label: {
                        Label(mission.isReady ? "Re-register barcode" : "Register a barcode",
                              systemImage: "barcode.viewfinder")
                    }
                    if let value = mission.barcodeValue {
                        LabeledContent("Registered", value: value)
                    }
                } footer: {
                    Text("Scan something far from your bed, like the toothpaste in the bathroom. "
                         + "You'll have to scan the same code to stop the crying.")
                }
            } else {
                Section("Difficulty") {
                    Picker("Difficulty", selection: $mission.difficulty) {
                        ForEach(MissionDifficulty.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Stepper("\(mission.rounds) \(mission.kind.roundsNoun)", value: $mission.rounds,
                            in: mission.kind.roundsRange, step: mission.kind.roundsStep)
                }
                Section {
                    Button { trying = true } label: { Label("Try it", systemImage: "play") }
                }
            }
        }
        .navigationTitle(mission.kind.title)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { onDone(mission) }
                    .bold()
                    .disabled(!mission.isReady)
            }
        }
        .sheet(isPresented: $scanning) {
            BarcodeScannerSheet { code in
                mission.barcodeValue = code
                scanning = false
            }
        }
        .sheet(isPresented: $trying) {
            NavigationStack {
                MissionContentView(mission: mission, resetToken: 0, onInteraction: {}) { trying = false }
                    .padding()
                    .navigationTitle("Practice")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Close") { trying = false } }
                    }
            }
        }
    }
}
