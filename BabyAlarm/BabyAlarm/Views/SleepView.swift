import SwiftUI

/// Sleep tab: wind-down sounds, a bedtime reminder, and overnight sound tracking.
struct SleepView: View {
    @EnvironmentObject private var sleep: SleepService
    @EnvironmentObject private var engine: AlarmEngine

    private var bedtime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: sleep.settings.bedtimeHour, minute: sleep.settings.bedtimeMinute,
                                      second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                sleep.settings.bedtimeHour = c.hour ?? 22
                sleep.settings.bedtimeMinute = c.minute ?? 30
            })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    trackingCard
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(SleepSoundCatalog.all) { sound in
                            let playing = sleep.playingSoundID == sound.id
                            Button {
                                sleep.toggleSound(sound)
                            } label: {
                                VStack(spacing: 6) {
                                    Text(sound.emoji).font(.system(size: 34))
                                    Text(sound.displayName).font(.caption.weight(.semibold)).multilineTextAlignment(.center)
                                    Image(systemName: playing ? "stop.fill" : "play.fill").font(.caption)
                                }
                                .frame(maxWidth: .infinity, minHeight: 104)
                                .background(playing ? Theme.lilac.opacity(0.35) : Color.gray.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(playing ? "Stop \(sound.displayName)" : "Play \(sound.displayName)")
                        }
                    }
                    .padding(.vertical, 6)
                    Picker("Stop after", selection: $sleep.settings.soundTimerMinutes) {
                        ForEach(SleepSettings.timerOptions, id: \.self) { m in
                            Text(m == 0 ? "Never" : "\(m) min").tag(m)
                        }
                    }
                } header: {
                    Text("Sleep sounds")
                } footer: {
                    Text("Real recordings that fade out when the timer ends. Credits are in Settings.")
                }

                Section {
                    Toggle("Bedtime reminder", isOn: $sleep.settings.bedtimeReminderEnabled)
                    if sleep.settings.bedtimeReminderEnabled {
                        DatePicker("Remind me at", selection: bedtime, displayedComponents: .hourAndMinute)
                    }
                    if let next = engine.nextAlarm() {
                        LabeledContent("Next alarm", value: next.date.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Sleep opportunity", value: sleepOpportunity(until: next.date))
                    }
                } header: {
                    Text("Wind down")
                }

                Section {
                    Toggle("Record snoring & sleep talk", isOn: $sleep.settings.recordSounds)
                } footer: {
                    Text("Recordings stay on this phone. Tracking stops by itself when an alarm rings.")
                }

                if !sleep.sessions.isEmpty {
                    Section("Past nights") {
                        ForEach(sleep.sessions) { session in
                            NavigationLink {
                                SleepSessionDetail(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(session.start.formatted(.dateTime.weekday(.wide).month().day()))
                                        .font(.headline)
                                    Text("\(durationText(session.duration)) · \(session.events.count) sound event\(session.events.count == 1 ? "" : "s")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { sleep.sessions[$0] }.forEach(sleep.deleteSession)
                        }
                    }
                }
            }
            .navigationTitle("Sleep")
            .onAppear { sleep.refreshPlayingSound() }
        }
    }

    private var trackingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let active = sleep.active {
                Text("😴 Sleeping since \(active.start.formatted(date: .omitted, time: .shortened))")
                    .font(.title3.weight(.bold))
                TimelineView(.periodic(from: .now, by: 30)) { ctx in
                    Text(durationText(ctx.date.timeIntervalSince(active.start)))
                        .font(.subheadline)
                }
                if active.recordingFile != nil {
                    LevelMeter(level: sleep.currentLevel)
                        .frame(height: 8)
                }
                PillButton(title: "I'm awake – stop tracking", systemImage: "sun.max.fill") { sleep.finishSleep() }
            } else {
                Text("🌙 Ready for bed?")
                    .font(.title3.weight(.bold))
                Text("Start tracking when you lie down. Leave the phone charging near the bed.")
                    .font(.subheadline)
                    .opacity(0.85)
                PillButton(title: "Start sleep", systemImage: "moon.fill") { sleep.startSleep() }
            }
        }
        .foregroundColor(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Theme.night, Theme.lilac], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private func sleepOpportunity(until date: Date) -> String {
        durationText(max(0, date.timeIntervalSince(Date())))
    }
}

func durationText(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds / 60)
    return minutes >= 60 ? "\(minutes / 60) h \(minutes % 60) min" : "\(minutes) min"
}

struct LevelMeter: View {
    let level: Double

    var body: some View {
        GeometryReader { geo in
            let fraction = min(1, max(0, (level + 60) / 60))
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.2))
                Capsule().fill(Color.white).frame(width: geo.size.width * fraction)
            }
        }
        .accessibilityLabel("Room loudness")
    }
}

struct SleepSessionDetail: View {
    @EnvironmentObject private var sleep: SleepService
    let session: SleepSession

    var body: some View {
        List {
            Section {
                LabeledContent("Went to bed", value: session.start.formatted(date: .omitted, time: .shortened))
                if let end = session.end {
                    LabeledContent("Woke up", value: end.formatted(date: .omitted, time: .shortened))
                }
                LabeledContent("Time asleep", value: durationText(session.duration))
                if let sound = SleepSoundCatalog.sound(id: session.soundID) {
                    LabeledContent("Sleep sound", value: "\(sound.emoji) \(sound.displayName)")
                }
            }
            Section {
                if session.events.isEmpty {
                    Text(session.recordingFile == nil ? "Recording was off this night." : "A quiet night: no snoring or talking detected.")
                        .foregroundColor(.secondary)
                }
                ForEach(session.loudestEvents) { event in
                    Button {
                        sleep.play(event, in: session)
                    } label: {
                        HStack {
                            Image(systemName: "play.circle.fill").font(.title2)
                            VStack(alignment: .leading) {
                                Text(session.start.addingTimeInterval(event.offset).formatted(date: .omitted, time: .shortened))
                                Text("\(Int(event.duration.rounded())) s · peak \(Int(event.peakLevel)) dB")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            } header: {
                Text("Loudest moments")
            } footer: {
                Text("Snoring, talking and other sounds louder than the room, detected on the phone. The 10 loudest are listed; tap one to hear it.")
            }
        }
        .navigationTitle(session.start.formatted(.dateTime.month().day()))
    }
}
