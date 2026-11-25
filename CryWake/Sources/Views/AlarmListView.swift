import SwiftUI

struct AlarmListView: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var engine: AlarmEngine

    private struct Editing: Identifiable {
        let alarm: Alarm
        let isNew: Bool
        var id: UUID { alarm.id }
    }

    @State private var editing: Editing?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NextAlarmHeader()
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                if store.alarms.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Text("\u{1F476}").font(.system(size: 48))
                            Text("No alarms yet").font(.headline)
                            Text("Add one and a real recorded baby will cry you awake.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    }
                }

                Section {
                    ForEach(store.sortedAlarms) { alarm in
                        AlarmRow(alarm: alarm)
                            .contentShape(Rectangle())
                            .onTapGesture { editing = Editing(alarm: alarm, isNew: false) }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { store.sortedAlarms[$0].id }
                        ids.forEach(store.delete(id:))
                    }
                }
            }
            .navigationTitle("Cry Wake")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = Editing(alarm: Alarm(), isNew: true)
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .accessibilityIdentifier("addAlarm")
                    .accessibilityLabel("Add alarm")
                }
            }
            .sheet(item: $editing) { item in
                AlarmEditView(draft: item.alarm, isNew: item.isNew)
            }
            .overlay(alignment: .bottom) {
                if !engine.notificationsAllowed {
                    Text("Notifications are off. Alarms only ring while Cry Wake is running.")
                        .font(.footnote)
                        .padding(10)
                        .background(.yellow.opacity(0.9), in: Capsule())
                        .padding()
                }
            }
        }
    }
}

struct NextAlarmHeader: View {
    @EnvironmentObject private var store: AlarmStore
    @EnvironmentObject private var engine: AlarmEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let next = store.nextAlarm(after: engine.now) {
                Text("Next cry in").font(.subheadline).opacity(0.85)
                Text(Self.countdown(from: engine.now, to: next.date))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(next.date.formatted(.dateTime.weekday(.wide).hour().minute()) + " \u{00B7} " +
                     (BabyVoice.voice(id: next.alarm.voiceID)?.name ?? "Baby"))
                    .font(.footnote)
                    .opacity(0.85)
            } else {
                Text("Sleep in").font(.subheadline).opacity(0.85)
                Text("No alarm set")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [Theme.night, Theme.accent], startPoint: .topLeading,
                                   endPoint: .bottomTrailing),
                    in: RoundedRectangle(cornerRadius: 20))
    }

    static func countdown(from now: Date, to date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSince(now)))
        let d = total / 86_400, h = (total % 86_400) / 3600, m = (total % 3600) / 60
        if d > 0 { return "\(d)d \(h)h \(m)m" }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m \(total % 60)s"
    }
}

struct AlarmRow: View {
    @EnvironmentObject private var store: AlarmStore
    let alarm: Alarm

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(alarm.timeText)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                HStack(spacing: 6) {
                    Text(alarm.displayLabel).fontWeight(.medium)
                    Text("\u{00B7} \(alarm.repeatText)")
                }
                .font(.subheadline)
                HStack(spacing: 10) {
                    Label(BabyVoice.voice(id: alarm.voiceID)?.name ?? "Baby", systemImage: "waveform")
                    if alarm.mission != .none {
                        Label(alarm.mission.title, systemImage: alarm.mission.systemImage)
                    }
                    if alarm.wakeUpCheck {
                        Image(systemName: "eye")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .opacity(alarm.isEnabled ? 1 : 0.45)
            Spacer()
            Toggle("", isOn: Binding(get: { alarm.isEnabled },
                                     set: { store.setEnabled($0, id: alarm.id) }))
                .labelsHidden()
                .accessibilityLabel("Enable \(alarm.displayLabel) at \(alarm.timeText)")
        }
        .padding(.vertical, 4)
    }
}
