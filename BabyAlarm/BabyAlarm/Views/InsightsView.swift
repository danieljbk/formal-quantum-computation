import Charts
import SwiftUI

/// Record tab: streaks, wake-up stats, charts and the history of every morning.
struct InsightsView: View {
    @EnvironmentObject private var engine: AlarmEngine
    @EnvironmentObject private var sleep: SleepService
    @State private var range = 7
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                let summary = Insights.summary(records: engine.history, now: Date())
                Section {
                    HStack(spacing: 12) {
                        stat("🔥", "\(summary.currentStreak)", "day streak")
                        stat("🏆", "\(summary.bestStreak)", "best streak")
                        stat("🌅", "\(summary.mornings)", "mornings")
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                    if let avg = summary.averageMinutesToGetUp {
                        LabeledContent("Average time to get up", value: String(format: "%.1f min", avg))
                    }
                    if let snoozes = summary.averageSnoozes {
                        LabeledContent("Average snoozes", value: String(format: "%.1f", snoozes))
                    }
                    if let rate = summary.onTimeRate {
                        LabeledContent("On-time mornings", value: "\(Int((rate * 100).rounded()))%")
                    }
                } footer: {
                    Text("A morning counts toward the streak when you snooze at most once and pass the wake-up check.")
                }

                Section {
                    Picker("Range", selection: $range) {
                        Text("Week").tag(7)
                        Text("Month").tag(30)
                    }
                    .pickerStyle(.segmented)

                    let wake = Insights.wakeSeries(records: engine.history, days: range, now: Date())
                    if wake.isEmpty {
                        Text("Dismiss an alarm to start your record.").foregroundColor(.secondary)
                    } else {
                        Text("Minutes from alarm to up").font(.subheadline.weight(.semibold))
                        Chart(wake) { point in
                            BarMark(x: .value("Day", point.day, unit: .day), y: .value("Minutes", point.value))
                                .foregroundStyle(Theme.pink.gradient)
                        }
                        .frame(height: 160)
                    }

                    let slept = Insights.sleepSeries(sessions: sleep.sessions, days: range, now: Date())
                    if !slept.isEmpty {
                        Text("Hours slept").font(.subheadline.weight(.semibold))
                        Chart(slept) { point in
                            BarMark(x: .value("Night", point.day, unit: .day), y: .value("Hours", point.value))
                                .foregroundStyle(Theme.lilac.gradient)
                            RuleMark(y: .value("Goal", 8))
                                .foregroundStyle(.secondary)
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        }
                        .frame(height: 160)
                    }
                } header: {
                    Text("Trends")
                }

                Section("History") {
                    if engine.history.isEmpty {
                        Text("No mornings yet.").foregroundColor(.secondary)
                    }
                    ForEach(Array(engine.history.reversed())) { record in
                        HStack(alignment: .top, spacing: 12) {
                            Text(record.isOnTime ? "✅" : "😴").font(.title2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.scheduled.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                                    .font(.headline)
                                Text("\(record.label) · up in \(String(format: "%.0f", record.minutesToGetUp)) min · \(record.snoozeCount) snooze\(record.snoozeCount == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if !record.missionKinds.isEmpty {
                                    Text(record.missionKinds.map(\.title).joined(separator: " → "))
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                if let passed = record.wakeCheckPassed {
                                    Text(passed ? "Wake-up check passed" : "Missed wake-up check")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundColor(passed ? .green : .orange)
                                }
                            }
                        }
                    }
                    if !engine.history.isEmpty {
                        Button("Clear history", role: .destructive) { confirmClear = true }
                    }
                }
            }
            .navigationTitle("Record")
            .confirmationDialog("Clear every recorded morning?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { engine.clearHistory() }
            }
        }
    }

    private func stat(_ emoji: String, _ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(emoji).font(.title2)
            Text(value).font(.title.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.lilac.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
