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

/// App root: five tabs, with ringing and wake-up checks presented full screen above all of them.
struct RootView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @StateObject private var settings = AppSettingsStore.shared
    @StateObject private var sleep = SleepService.shared

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
        TabView {
            ContentView()
                .tabItem { Label("Alarm", systemImage: "alarm.fill") }
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon.zzz.fill") }
            MorningView()
                .tabItem { Label("Morning", systemImage: "sun.horizon.fill") }
            InsightsView()
                .tabItem { Label("Record", systemImage: "chart.bar.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .environmentObject(settings)
        .environmentObject(sleep)
        .tint(Theme.lilac)
        .preferredColorScheme(settings.prefs.theme.colorScheme)
        .fullScreenCover(item: interruption) { item in
            switch item {
            case .ringing(let session):
                RingingView(session: session).environmentObject(engine)
            case .wakeCheck(let check):
                WakeCheckView(check: check).environmentObject(engine)
            }
        }
        .sheet(isPresented: $engine.showBriefing) {
            NavigationStack {
                BriefingContent(showsHeader: true)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Start my day") { engine.showBriefing = false }
                        }
                    }
            }
            .environmentObject(settings)
            .environmentObject(engine)
            .environmentObject(sleep)
        }
    }
}

/// Alarm tab: next-alarm header, the alarm list, and a floating add button.
struct ContentView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @EnvironmentObject private var settings: AppSettingsStore
    @State private var editor: EditorTarget?
    @State private var showQuick = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
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

                    Section {
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    engine.delete(id: alarm.id)
                                } label: { Label("Delete", systemImage: "trash") }
                                Button {
                                    editor = EditorTarget(alarm: alarm, isNew: false)
                                } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(Theme.lilac)
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    engine.duplicate(id: alarm.id)
                                } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                    .tint(.teal)
                                if !alarm.repeatDays.isEmpty && alarm.isEnabled {
                                    if alarm.skippedOccurrence == nil {
                                        Button {
                                            engine.skipNext(id: alarm.id)
                                        } label: { Label("Skip next", systemImage: "forward.end") }
                                            .tint(.orange)
                                    } else {
                                        Button {
                                            engine.clearSkip(id: alarm.id)
                                        } label: { Label("Don't skip", systemImage: "arrow.uturn.backward") }
                                            .tint(.orange)
                                    }
                                }
                            }
                            .contextMenu {
                                Button { editor = EditorTarget(alarm: alarm, isNew: false) } label: { Label("Edit", systemImage: "pencil") }
                                Button { engine.duplicate(id: alarm.id) } label: { Label("Duplicate", systemImage: "plus.square.on.square") }
                                Button(role: .destructive) { engine.delete(id: alarm.id) } label: { Label("Delete", systemImage: "trash") }
                            }
                        }
                    } header: {
                        Text("Alarms")
                    } footer: {
                        Text("Swipe right to duplicate or skip the next ring, left to edit or delete.")
                    }
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 72) }

                Button(action: newAlarm) {
                    Image(systemName: "plus")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(Theme.headerGradient)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                }
                .accessibilityLabel("Add alarm")
                .padding(.trailing, 20)
                .padding(.bottom, 16)
            }
            .navigationTitle("Baby Alarm")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showQuick = true } label: { Label("Quick alarm", systemImage: "bolt.fill") }
                }
            }
            .sheet(item: $editor) { target in
                AlarmEditorView(alarm: target.alarm, isNew: target.isNew)
                    .environmentObject(engine)
                    .environmentObject(settings)
            }
            .sheet(isPresented: $showQuick) {
                QuickAlarmView()
                    .environmentObject(engine)
                    .presentationDetents([.medium, .large])
            }
        }
    }

    private func newAlarm() {
        var fresh = Alarm()
        fresh.voiceID = engine.defaultVoiceID
        fresh.missions = settings.prefs.defaultMissions.map { var m = $0; m.id = UUID(); return m }
        let c = Calendar.current.dateComponents([.hour, .minute], from: Date().addingTimeInterval(8 * 3600))
        fresh.hour = c.hour ?? 7
        fresh.minute = c.minute ?? 0
        editor = EditorTarget(alarm: fresh, isNew: true)
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
                if let skipped = alarm.skippedOccurrence, skipped > Date() {
                    Label("Skipping \(skipped.formatted(.dateTime.weekday(.wide)))", systemImage: "forward.end.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.orange)
                }
                HStack(spacing: 12) {
                    Label(BabyVoiceCatalog.displayName(for: alarm.voiceID), systemImage: "waveform")
                    if !alarm.activeMissions.isEmpty {
                        Label(alarm.missionSummary, systemImage: alarm.activeMissions[0].kind.symbolName)
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
