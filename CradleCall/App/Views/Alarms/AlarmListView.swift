import SwiftUI

struct AlarmListView: View {
    @Environment(AppModel.self) private var model
    @State private var editing: WakeAlarm?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NextAlarmBanner()
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                if model.alarms.isEmpty {
                    ContentUnavailableView("No alarms", systemImage: "alarm",
                                           description: Text("Tap + to have a baby wake you up."))
                }
                ForEach(model.alarms) { alarm in
                    AlarmRow(alarm: alarm)
                        .contentShape(Rectangle())
                        .onTapGesture { editing = alarm }
                        .swipeActions {
                            Button(role: .destructive) { model.deleteAlarm(alarm.id) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .contextMenu { contextMenu(for: alarm) }
                }
            }
            .navigationTitle("CradleCall")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { isCreating = true } label: { Label("New alarm", systemImage: "alarm") }
                        Section("Quick alarm") {
                            ForEach([1, 5, 10, 20, 30, 60], id: \.self) { minutes in
                                Button("In \(minutes) min") { model.addQuickAlarm(minutes: minutes) }
                            }
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(item: $editing) { alarm in
                AlarmEditorView(alarm: alarm, isNew: false)
            }
            .sheet(isPresented: $isCreating) {
                AlarmEditorView(alarm: model.newAlarmTemplate(), isNew: true)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for alarm: WakeAlarm) -> some View {
        Button { model.preview(alarm) } label: { Label("Preview ring", systemImage: "play.circle") }
        if alarm.isRepeating && alarm.isEnabled {
            if alarm.skippedOccurrence == nil {
                Button { model.skipNext(alarm.id) } label: { Label("Skip next", systemImage: "forward.end") }
            } else {
                Button { model.clearSkip(alarm.id) } label: {
                    Label("Don't skip", systemImage: "arrow.uturn.backward")
                }
            }
        }
        Button(role: .destructive) { model.deleteAlarm(alarm.id) } label: {
            Label("Delete", systemImage: "trash")
        }
    }
}

struct NextAlarmBanner: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("👶").font(.system(size: 44))
                VStack(alignment: .leading) {
                    if let next = model.nextRing {
                        Text(AlarmSchedule.countdownText(from: model.now, to: next.date))
                            .font(.title3.bold())
                        Text("\(next.date.formatted(date: .abbreviated, time: .shortened)) · "
                             + model.voice(id: next.alarm.voiceID).name)
                            .font(.subheadline)
                            .opacity(0.85)
                    } else {
                        Text("No alarm set").font(.title3.bold())
                        Text("The baby is sleeping peacefully.").font(.subheadline).opacity(0.85)
                    }
                }
            }
            if let snoozed = model.snoozedUntil {
                Label("Snoozed until \(snoozed.formatted(date: .omitted, time: .shortened))",
                      systemImage: "zzz")
                    .font(.footnote.bold())
            }
            if !model.alarmKitAuthorized && !model.notificationsAuthorized {
                Label("Allow alarms or notifications in Settings so the baby can wake you.",
                      systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.ringingGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.vertical, 4)
    }
}

struct AlarmRow: View {
    @Environment(AppModel.self) private var model
    let alarm: WakeAlarm

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeText)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text("\(alarm.label) · \(alarm.repeatSummary)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                    Text(model.voice(id: alarm.voiceID).name)
                    ForEach(alarm.missions) { mission in
                        Image(systemName: mission.kind.symbol)
                    }
                }
                .font(.caption)
                .foregroundStyle(Theme.accent)
                if alarm.skippedOccurrence != nil {
                    Label("Next ring skipped", systemImage: "forward.end.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(get: { alarm.isEnabled },
                                            set: { model.setEnabled(alarm.id, $0) }))
                .labelsHidden()
        }
        .opacity(alarm.isEnabled ? 1 : 0.55)
        .padding(.vertical, 4)
    }
}
