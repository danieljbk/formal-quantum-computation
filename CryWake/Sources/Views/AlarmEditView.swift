import SwiftUI

struct AlarmEditView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var engine: AlarmEngine
    @Environment(\.dismiss) private var dismiss

    @State var draft: Alarm
    let isNew: Bool

    private static let snoozeOptions = [0, 1, 3, 5, 10, 15, 20]
    private static let maxSnoozeOptions: [Int?] = [1, 3, 5, 10, nil]

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(from: DateComponents(hour: draft.hour, minute: draft.minute)) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                draft.hour = c.hour ?? 7
                draft.minute = c.minute ?? 0
            })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    TextField("Label", text: $draft.label)
                    WeekdayPicker(selection: $draft.repeatDays)
                }

                Section("Baby voice") {
                    NavigationLink {
                        VoicePickerView(selection: $draft.voiceID)
                    } label: {
                        HStack {
                            Text("Voice")
                            Spacer()
                            Text(BabyVoice.voice(id: draft.voiceID)?.name ?? "\u{2014}")
                                .foregroundStyle(.secondary)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Volume \(Int(draft.volume * 100))%")
                        Slider(value: $draft.volume, in: 0.1...1)
                    }
                    Toggle("Start softly, get louder", isOn: $draft.gradualVolume)
                    if draft.gradualVolume {
                        Stepper("Fade in over \(Int(draft.fadeInSeconds)) s", value: $draft.fadeInSeconds,
                                in: 10...120, step: 10)
                    }
                    Toggle("Vibrate", isOn: $draft.vibrate)
                }

                Section("Snooze") {
                    Picker("Snooze length", selection: $draft.snoozeMinutes) {
                        ForEach(Self.snoozeOptions, id: \.self) { m in
                            Text(m == 0 ? "Off" : "\(m) min").tag(m)
                        }
                    }
                    if draft.snoozeMinutes > 0 {
                        Picker("Snooze limit", selection: $draft.maxSnoozes) {
                            ForEach(Self.maxSnoozeOptions, id: \.self) { n in
                                Text(n.map { "\($0) times" } ?? "Unlimited").tag(n)
                            }
                        }
                    }
                }

                Section {
                    Picker("Mission", selection: $draft.mission) {
                        ForEach(MissionKind.allCases) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    if draft.mission != .none {
                        Picker("Difficulty", selection: $draft.missionDifficulty) {
                            ForEach(MissionDifficulty.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Stepper("Rounds: \(draft.missionRounds)", value: $draft.missionRounds, in: 1...5)
                    }
                } header: {
                    Text("Mission to stop the crying")
                } footer: {
                    Text(draft.mission.explanation)
                }

                Section {
                    Toggle("Wake-up check", isOn: $draft.wakeUpCheck)
                    if draft.wakeUpCheck {
                        Stepper("Confirm within \(draft.wakeUpCheckMinutes) min",
                                value: $draft.wakeUpCheckMinutes, in: 1...15)
                    }
                } footer: {
                    Text("After you soothe the baby you must tap \u{201C}I'm awake\u{201D} in time, or the crying starts again.")
                }

                Section {
                    Button {
                        engine.test(draft)
                    } label: {
                        Label("Hear it now", systemImage: "play.circle")
                    }
                    if !isNew {
                        Button(role: .destructive) {
                            store.delete(id: draft.id)
                            dismiss()
                        } label: {
                            Label("Delete alarm", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New alarm" : "Edit alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = draft
                        saved.isEnabled = true
                        store.upsert(saved)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .accessibilityIdentifier("saveAlarm")
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>
    private let order: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeat").font(.subheadline)
            HStack(spacing: 6) {
                ForEach(order) { day in
                    let on = selection.contains(day)
                    Button {
                        if on { selection.remove(day) } else { selection.insert(day) }
                    } label: {
                        Text(day.initial)
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 36, height: 36)
                            .background(on ? Theme.accent : Color.secondary.opacity(0.15), in: Circle())
                            .foregroundStyle(on ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.shortName)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(.vertical, 4)
    }
}
