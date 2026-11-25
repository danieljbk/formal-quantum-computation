import SwiftUI
import UserNotifications

/// Something that takes over the whole screen: a ringing alarm or a wake-up check.
enum Interruption: Identifiable {
    case ringing(RingingSession)
    case wakeCheck(WakeCheckSession)

    var id: String {
        switch self {
        case .ringing(let r): return "ring-\(r.key.string)-\(r.snoozeCount)"
        case .wakeCheck(let w): return "check-\(w.key.string)"
        }
    }
}

struct EditorTarget: Identifiable {
    let alarm: Alarm
    let isNew: Bool
    var id: UUID { alarm.id }
}

struct ContentView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @State private var editor: EditorTarget?
    @State private var showQuick = false
    @State private var showSettings = false

    private var interruption: Binding<Interruption?> {
        Binding(
            get: {
                if let r = engine.ringing { return .ringing(r) }
                if let w = engine.wakeCheck { return .wakeCheck(w) }
                return nil
            },
            set: { _ in })
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NextAlarmHeader()
                        .listRowInsets(EdgeInsets())
                }

                if engine.notificationStatus == .denied {
                    Section {
                        Label {
                            Text("Notifications are off, so alarms can only ring while the app is open. Turn them on in Settings.")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "bell.slash.fill").foregroundColor(.orange)
                        }
                    }
                }

                Section("Alarms") {
                    if engine.alarms.isEmpty {
                        Text("No alarms yet. Tap + to add one.")
                            .foregroundColor(.secondary)
                    }
                    ForEach(engine.alarms) { alarm in
                        AlarmRow(alarm: alarm) { enabled in
                            engine.setEnabled(enabled, id: alarm.id)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editor = EditorTarget(alarm: alarm, isNew: false) }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { engine.alarms[$0].id }
                        ids.forEach { engine.delete(id: $0) }
                    }
                }
            }
            .navigationTitle("Baby Alarm")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showQuick = true } label: { Image(systemName: "bolt.fill") }
                        .accessibilityLabel("Quick alarm")
                    Button {
                        var fresh = Alarm()
                        let c = Calendar.current.dateComponents([.hour, .minute], from: Date().addingTimeInterval(8 * 3600))
                        fresh.hour = c.hour ?? 7
                        fresh.minute = c.minute ?? 0
                        editor = EditorTarget(alarm: fresh, isNew: true)
                    } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add alarm")
                }
            }
            .sheet(item: $editor) { target in
                AlarmEditorView(alarm: target.alarm, isNew: target.isNew)
                    .environmentObject(engine)
            }
            .sheet(isPresented: $showQuick) {
                QuickAlarmView()
                    .environmentObject(engine)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(engine)
            }
        }
        .tint(Theme.lilac)
        .fullScreenCover(item: interruption) { item in
            switch item {
            case .ringing(let session):
                RingingView(session: session).environmentObject(engine)
            case .wakeCheck(let check):
                WakeCheckView(check: check).environmentObject(engine)
            }
        }
    }
}

struct NextAlarmHeader: View {
    @EnvironmentObject private var engine: AlarmEngine

    var body: some View {
        TimelineView(.periodic(from: .now, by: 15)) { context in
            let next = engine.nextAlarm(after: context.date)
            VStack(alignment: .leading, spacing: 6) {
                Text(next == nil ? "😴" : BabyVoiceCatalog.resolve(next!.alarm.voiceID, for: next!.date).emoji)
                    .font(.system(size: 44))
                if let next {
                    Text(AlarmSchedule.countdownText(from: context.date, to: next.date))
                        .font(.title2.weight(.bold))
                    Text("\(BabyVoiceCatalog.resolve(next.alarm.voiceID, for: next.date).displayName) baby wakes you at \(next.date.formatted(date: .omitted, time: .shortened)) · \(next.alarm.displayLabel)")
                        .font(.subheadline)
                        .opacity(0.85)
                } else {
                    Text("No alarm set")
                        .font(.title2.weight(.bold))
                    Text("Turn on an alarm and a baby will cry you awake.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.headerGradient)
        }
    }
}

struct AlarmRow: View {
    let alarm: Alarm
    let onToggle: (Bool) -> Void

    private var timeText: String {
        if let shot = alarm.oneShotDate {
            return shot.formatted(date: .omitted, time: .shortened)
        }
        return AlarmSchedule.timeText(hour: alarm.hour, minute: alarm.minute)
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(timeText)
                    .font(.system(size: 42, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text("\(alarm.displayLabel) · \(alarm.oneShotDate == nil ? AlarmSchedule.repeatSummary(alarm.repeatDays) : "Once")")
                    .font(.subheadline)
                HStack(spacing: 12) {
                    Label(BabyVoiceCatalog.displayName(for: alarm.voiceID), systemImage: "waveform")
                    if alarm.mission.kind != .none {
                        Label(alarm.mission.kind.title, systemImage: alarm.mission.kind.symbolName)
                    }
                    if alarm.wakeUpCheck.isEnabled {
                        Label("Check", systemImage: "checkmark.seal")
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            Spacer()
            Toggle("Enabled", isOn: Binding(get: { alarm.isEnabled }, set: onToggle))
                .labelsHidden()
        }
        .padding(.vertical, 4)
        .opacity(alarm.isEnabled ? 1 : 0.55)
    }
}
