import SwiftUI

struct AlarmEditorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var alarm: WakeAlarm
    @State private var addingMission = false
    @State private var editingMission: MissionConfig?
    let isNew: Bool

    init(alarm: WakeAlarm, isNew: Bool) {
        _alarm = State(initialValue: alarm)
        self.isNew = isNew
    }

    private var time: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date())
                    ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                alarm.hour = comps.hour ?? 0
                alarm.minute = comps.minute ?? 0
                alarm.oneShotDate = nil
            })
    }

    private var missionsInvalid: Bool {
        (model.settings.antiCheat.requireMission && alarm.missions.isEmpty)
            || alarm.missions.contains { !$0.isReady }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    if let next = AlarmSchedule.nextFireDate(for: alarm, after: Date()) {
                        Text(AlarmSchedule.countdownText(from: Date(), to: next))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                Section("Repeat") {
                    WeekdayPicker(selection: $alarm.repeatDays)
                    TextField("Label", text: $alarm.label)
                }

                Section {
                    NavigationLink {
                        VoicePickerView(selection: $alarm.voiceID)
                    } label: {
                        LabeledContent("Baby voice", value: model.voice(id: alarm.voiceID).name)
                    }
                } header: {
                    Text("Crying baby")
                } footer: {
                    Text("Real recordings of real babies. You can also record your own little one.")
                }

                Section {
                    ForEach(alarm.missions) { mission in
                        Button { editingMission = mission } label: {
                            HStack {
                                Image(systemName: mission.kind.symbol)
                                    .frame(width: 28)
                                    .foregroundStyle(Theme.accent)
                                VStack(alignment: .leading) {
                                    Text(mission.kind.title).foregroundStyle(.primary)
                                    Text(mission.summary).font(.caption)
                                        .foregroundStyle(mission.isReady ? Color.secondary : Color.red)
                                }
                            }
                        }
                    }
                    .onDelete { alarm.missions.remove(atOffsets: $0) }
                    .onMove { alarm.missions.move(fromOffsets: $0, toOffset: $1) }
                    if alarm.missions.count < 5 {
                        Button { addingMission = true } label: {
                            Label("Add mission", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Wake-up missions")
                } footer: {
                    Text("The baby only stops crying once every mission is done.")
                }

                Section("Sound") {
                    VStack(alignment: .leading) {
                        Text("Volume \(Int(alarm.sound.volume * 100))%")
                        Slider(value: $alarm.sound.volume, in: 0.1...1)
                    }
                    Toggle("Gradually louder", isOn: $alarm.sound.gradualIncrease)
                    if alarm.sound.gradualIncrease {
                        Picker("Reach full volume in", selection: $alarm.sound.rampSeconds) {
                            ForEach([15.0, 30, 45, 60, 120], id: \.self) { seconds in
                                Text("\(Int(seconds)) s").tag(seconds)
                            }
                        }
                    }
                    Toggle("Vibrate", isOn: $alarm.sound.vibrate)
                }

                Section("Snooze") {
                    Toggle("Allow snooze", isOn: $alarm.snooze.isEnabled)
                    if alarm.snooze.isEnabled {
                        Stepper("Every \(alarm.snooze.minutes) min", value: $alarm.snooze.minutes, in: 1...30)
                        Picker("Limit", selection: $alarm.snooze.maxCount) {
                            Text("Unlimited").tag(0)
                            ForEach(1...10, id: \.self) { Text("\($0) times").tag($0) }
                        }
                    }
                }

                Section {
                    Toggle("Wake-up check", isOn: $alarm.wakeUpCheck.isEnabled)
                    if alarm.wakeUpCheck.isEnabled {
                        Picker("Ask after", selection: $alarm.wakeUpCheck.delayMinutes) {
                            ForEach([3, 5, 10, 15], id: \.self) { Text("\($0) min").tag($0) }
                        }
                        Picker("Time to answer", selection: $alarm.wakeUpCheck.responseSeconds) {
                            ForEach([60, 100, 180], id: \.self) { Text("\($0) s").tag($0) }
                        }
                    }
                    Toggle("Morning briefing", isOn: $alarm.showsBriefing)
                } header: {
                    Text("After waking")
                } footer: {
                    Text("If you don't confirm you're awake, the baby starts crying again.")
                }

                Section {
                    Button {
                        let previewed = alarm
                        model.upsert(previewed)
                        dismiss()
                        // Present the ringing screen once this sheet has gone.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { model.preview(previewed) }
                    } label: {
                        Label("Save & preview ring", systemImage: "play.circle.fill")
                    }
                    .disabled(missionsInvalid)
                    if !isNew {
                        Button(role: .destructive) {
                            model.deleteAlarm(alarm.id)
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
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var saved = alarm
                        saved.isEnabled = true
                        model.upsert(saved)
                        dismiss()
                    }
                    .bold()
                    .disabled(missionsInvalid)
                }
            }
            .sheet(isPresented: $addingMission) {
                MissionPickerView { mission in alarm.missions.append(mission) }
            }
            .sheet(item: $editingMission) { mission in
                MissionConfigView(mission: mission) { updated in
                    if let index = alarm.missions.firstIndex(where: { $0.id == updated.id }) {
                        alarm.missions[index] = updated
                    }
                }
            }
        }
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.allCases) { day in
                let isOn = selection.contains(day)
                Button {
                    if isOn { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(day.initial)
                        .font(.subheadline.bold())
                        .frame(width: 36, height: 36)
                        .background(isOn ? Theme.accent : Color.secondary.opacity(0.15), in: Circle())
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.shortName)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}
