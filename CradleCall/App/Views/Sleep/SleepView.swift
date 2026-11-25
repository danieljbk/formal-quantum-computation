import Charts
import SwiftUI

struct SleepView: View {
    @Environment(AppModel.self) private var model
    @State private var addingSleep = false

    private var bedtime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: model.settings.bedtimeHour,
                                      minute: model.settings.bedtimeMinute, second: 0, of: Date()) ?? Date()
            },
            set: { date in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
                model.updateSettings {
                    $0.bedtimeHour = comps.hour ?? 22
                    $0.bedtimeMinute = comps.minute ?? 30
                }
            })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    sessionCard
                    chartCard
                    bedtimeCard
                    recentCard
                }
                .padding()
            }
            .navigationTitle("Sleep")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addingSleep = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Log a past night")
                }
            }
            .sheet(isPresented: $addingSleep) { AddSleepView() }
        }
    }

    private var sessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let active = model.activeSleep {
                Text("Sleeping since \(active.start.formatted(date: .omitted, time: .shortened))")
                    .font(.headline)
                Text(InsightsCalculator.formatDuration(model.now.timeIntervalSince(active.start)))
                    .font(.system(size: 44, weight: .light, design: .rounded).monospacedDigit())
                Text("Dismissing your alarm ends this sleep automatically.")
                    .font(.footnote)
                    .opacity(0.8)
                Button { model.endSleep() } label: {
                    Label("I'm up", systemImage: "sun.max.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.warm)
            } else {
                Text("Ready for bed?").font(.headline)
                if let next = model.nextRing {
                    let hours = next.date.timeIntervalSince(model.now) / 3600
                    Text(String(format: "Going to sleep now gives you %.1f h before the baby cries.", hours))
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Button { model.startSleep() } label: {
                    Label("Start sleeping", systemImage: "moon.zzz.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.nightGradient, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var chartCard: some View {
        let days = InsightsCalculator.sleepHoursByDay(sleeps: model.state.sleeps, days: 7, now: model.now)
        let goal = model.settings.sleepGoalHours
        return Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Last 7 nights").font(.headline)
                Chart {
                    ForEach(days) { day in
                        BarMark(x: .value("Day", day.day, unit: .day), y: .value("Hours", day.value))
                            .foregroundStyle(day.value >= goal ? Theme.accent : Theme.warm)
                            .cornerRadius(4)
                    }
                    RuleMark(y: .value("Goal", goal))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                        .annotation(position: .top, alignment: .leading) {
                            Text("Goal \(Int(goal)) h").font(.caption2).foregroundStyle(.secondary)
                        }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.narrow))
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var bedtimeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Bedtime").font(.headline)
                DatePicker("Target bedtime", selection: bedtime, displayedComponents: .hourAndMinute)
                Toggle("Bedtime reminder", isOn: Binding(
                    get: { model.settings.bedtimeReminderEnabled },
                    set: { value in model.updateSettings { $0.bedtimeReminderEnabled = value } }))
                if model.settings.bedtimeReminderEnabled {
                    Picker("Remind me", selection: Binding(
                        get: { model.settings.bedtimeReminderLeadMinutes },
                        set: { value in model.updateSettings { $0.bedtimeReminderLeadMinutes = value } })) {
                        ForEach([0, 15, 30, 45, 60], id: \.self) { Text($0 == 0 ? "At bedtime" : "\($0) min before").tag($0) }
                    }
                }
                Stepper(String(format: "Sleep goal %.1f h", model.settings.sleepGoalHours),
                        value: Binding(get: { model.settings.sleepGoalHours },
                                       set: { value in model.updateSettings { $0.sleepGoalHours = value } }),
                        in: 4...12, step: 0.5)
            }
        }
    }

    private var recentCard: some View {
        let recent = model.state.sleeps.filter { $0.end != nil }.sorted { $0.start > $1.start }.prefix(10)
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recent sleep").font(.headline)
                if recent.isEmpty {
                    Text("Tap “Start sleeping” at bedtime to track your nights.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(recent)) { session in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(session.start.formatted(.dateTime.weekday(.wide).day().month()))
                            Text("\(session.start.formatted(date: .omitted, time: .shortened)) – "
                                 + (session.end?.formatted(date: .omitted, time: .shortened) ?? ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(InsightsCalculator.formatDuration(session.duration ?? 0))
                            .font(.subheadline.monospacedDigit())
                        Menu {
                            ForEach(1...5, id: \.self) { stars in
                                Button(String(repeating: "★", count: stars)) {
                                    model.rateSleep(session.id, rating: stars)
                                }
                            }
                            Button("Delete", role: .destructive) { model.deleteSleep(session.id) }
                        } label: {
                            Text(session.rating.map { String(repeating: "★", count: $0) } ?? "Rate")
                                .font(.caption)
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    Divider()
                }
            }
        }
    }
}

struct AddSleepView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var start = Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date()
    @State private var end = Date()

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Fell asleep", selection: $start)
                DatePicker("Woke up", selection: $end)
                if end <= start {
                    Text("Wake time must be after the time you fell asleep.").foregroundStyle(.red)
                }
            }
            .navigationTitle("Log sleep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        model.addSleep(start: start, end: end)
                        dismiss()
                    }
                    .disabled(end <= start)
                }
            }
        }
    }
}
