import SwiftUI

struct AlarmEditorView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @Environment(\.dismiss) private var dismiss

    @State private var alarm: Alarm
    @State private var time: Date
    private let originalTime: Date
    let isNew: Bool

    init(alarm: Alarm, isNew: Bool) {
        self.isNew = isNew
        _alarm = State(initialValue: alarm)
        let t = Calendar.current.date(bySettingHour: alarm.hour, minute: alarm.minute, second: 0, of: Date()) ?? Date()
        _time = State(initialValue: t)
        originalTime = t
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                }

                Section("Repeat") {
                    WeekdayPicker(selection: $alarm.repeatDays)
                    HStack {
                        presetButton("Weekdays", Weekday.weekdays)
                        presetButton("Weekends", Weekday.weekend)
                        presetButton("Every day", Set(Weekday.allCases))
                        presetButton("Once", [])
                    }
                    .font(.caption)
                }

                Section("Label") {
                    TextField("Alarm name", text: $alarm.label)
                }

                Section {
                    NavigationLink {
                        VoicePickerView(voiceID: $alarm.voiceID)
                    } label: {
                        LabeledContent("Baby voice", value: BabyVoiceCatalog.displayName(for: alarm.voiceID))
                    }
                } header: {
                    Text("Alarm sound")
                } footer: {
                    Text("Every alarm sound is a real recording of a crying baby.")
                }

                Section {
                    ForEach($alarm.missions) { $mission in
                        NavigationLink {
                            MissionEditorView(mission: $mission)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: mission.kind.symbolName)
                                    .frame(width: 28)
                                    .foregroundColor(Theme.lilac)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mission.kind.title)
                                    Text(mission.isReady ? mission.kind.roundsLabel(mission.rounds) : "Needs setup: tap to register")
                                        .font(.caption)
                                        .foregroundColor(mission.isReady ? .secondary : .orange)
                                }
                            }
                        }
                    }
                    .onDelete { alarm.missions.remove(atOffsets: $0) }
                    .onMove { alarm.missions.move(fromOffsets: $0, toOffset: $1) }
                    if alarm.missions.count < Alarm.maxMissions {
                        Menu {
                            ForEach(MissionKind.selectable) { kind in
                                Button {
                                    alarm.missions.append(MissionSettings(kind: kind))
                                } label: {
                                    Label(kind.title, systemImage: kind.symbolName)
                                }
                            }
                        } label: {
                            Label("Add mission", systemImage: "plus.circle.fill")
                        }
                    }
                } header: {
                    Text("Wake-up missions")
                } footer: {
                    Text(alarm.missions.isEmpty
                         ? "Without a mission, one tap stops the crying."
                         : "The baby keeps crying until every mission is done, in this order (up to \(Alarm.maxMissions)). Swipe to remove.")
                }

                Section("Snooze") {
                    Toggle("Snooze", isOn: $alarm.snooze.isEnabled)
                    if alarm.snooze.isEnabled {
                        Picker("Length", selection: $alarm.snooze.minutes) {
                            ForEach(SnoozeSettings.minuteOptions, id: \.self) { Text("\($0) min").tag($0) }
                        }
                        Picker("Limit", selection: $alarm.snooze.maxCount) {
                            ForEach(SnoozeSettings.countOptions, id: \.self) { n in
                                Text(n == 0 ? "Unlimited" : "\(n)×").tag(n)
                            }
                        }
                    }
                }

                Section("Sound") {
                    HStack {
                        Image(systemName: "speaker.fill").foregroundColor(.secondary)
                        Slider(value: $alarm.volume, in: 0.1...1)
                        Image(systemName: "speaker.wave.3.fill").foregroundColor(.secondary)
                    }
                    Picker("Gradually louder", selection: $alarm.gradualVolumeSeconds) {
                        ForEach(Alarm.gradualOptions, id: \.self) { s in
                            Text(s == 0 ? "Off" : "\(s) s").tag(s)
                        }
                    }
                    Toggle("Vibrate", isOn: $alarm.vibrate)
                    Toggle(isOn: $alarm.cryEscalation) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fussier over time")
                            Text("Every \(Int(CryEscalation.stageSeconds)) s a more upset baby takes over")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Wake-up check", isOn: $alarm.wakeUpCheck.isEnabled)
                    if alarm.wakeUpCheck.isEnabled {
                        Picker("Check after", selection: $alarm.wakeUpCheck.delayMinutes) {
                            ForEach(WakeUpCheckSettings.delayOptions, id: \.self) { Text("\($0) min").tag($0) }
                        }
                    }
                } header: {
                    Text("Wake-up check")
                } footer: {
                    Text("A while after you dismiss, we ask if you're up. Miss it and the baby cries again.")
                }

                if !isNew {
                    Section {
                        Button("Delete alarm", role: .destructive) {
                            engine.delete(id: alarm.id)
                            dismiss()
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
                    Button { save() } label: { Text("Save").bold() }
                }
            }
        }
    }

    private func presetButton(_ title: String, _ days: Set<Weekday>) -> some View {
        Button(title) { alarm.repeatDays = days }
            .buttonStyle(.bordered)
            .tint(alarm.repeatDays == days ? Theme.lilac : .gray)
    }

    private func save() {
        let c = Calendar.current.dateComponents([.hour, .minute], from: time)
        alarm.hour = c.hour ?? alarm.hour
        alarm.minute = c.minute ?? alarm.minute
        if time != originalTime || !alarm.repeatDays.isEmpty {
            alarm.oneShotDate = nil
        }
        alarm.isEnabled = true
        engine.save(alarm)
        dismiss()
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Weekday>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Weekday.displayOrder, id: \.self) { day in
                let on = selection.contains(day)
                Button {
                    if on { selection.remove(day) } else { selection.insert(day) }
                } label: {
                    Text(day.initial)
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 36, height: 36)
                        .background(on ? Theme.lilac : Color.gray.opacity(0.15))
                        .foregroundColor(on ? .white : .primary)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.shortName)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
    }
}

struct VoicePickerView: View {
    @Binding var voiceID: String
    @State private var playing: String?

    var body: some View {
        List {
            Section {
                ForEach(BabyVoiceCatalog.all) { voice in
                    HStack(spacing: 14) {
                        Text(voice.emoji).font(.system(size: 36))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.displayName).font(.headline)
                            Text(voice.blurb).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            togglePreview(voice)
                        } label: {
                            Image(systemName: playing == voice.id ? "stop.circle.fill" : "play.circle.fill")
                                .font(.title)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(playing == voice.id ? "Stop preview" : "Play preview")
                        Image(systemName: "checkmark")
                            .foregroundColor(Theme.lilac)
                            .opacity(voiceID == voice.id ? 1 : 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { voiceID = voice.id }
                }
            } header: {
                Text("Choose your baby")
            }

            Section {
                HStack(spacing: 14) {
                    Text("🎲").font(.system(size: 36))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Surprise baby").font(.headline)
                        Text("A different baby every morning.").font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark")
                        .foregroundColor(Theme.lilac)
                        .opacity(voiceID == BabyVoiceCatalog.randomID ? 1 : 0)
                }
                .contentShape(Rectangle())
                .onTapGesture { voiceID = BabyVoiceCatalog.randomID }
            }
        }
        .navigationTitle("Baby voice")
        .onDisappear {
            AudioService.shared.stopPreview()
            playing = nil
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

struct QuickAlarmView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @Environment(\.dismiss) private var dismiss
    @State private var voiceID = AlarmEngine.shared.defaultVoiceID

    private let options = [1, 5, 10, 15, 20, 30, 45, 60, 90]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Nap or timer: the baby cries once when time is up.")
                    .foregroundColor(.secondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(options, id: \.self) { minutes in
                        Button {
                            engine.addQuickAlarm(minutes: minutes, voiceID: voiceID)
                            dismiss()
                        } label: {
                            VStack(spacing: 2) {
                                Text("+\(minutes)").font(.title2.weight(.bold)).monospacedDigit()
                                Text("min").font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Theme.lilac.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Picker("Baby voice", selection: $voiceID) {
                    ForEach(BabyVoiceCatalog.all) { v in Text("\(v.emoji) \(v.displayName)").tag(v.id) }
                }
                .pickerStyle(.menu)
                Spacer()
            }
            .padding()
            .navigationTitle("Quick alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
        }
    }
}
