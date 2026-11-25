import Charts
import SwiftUI

struct InsightsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirmClear = false

    var body: some View {
        let summary = InsightsCalculator.summarize(records: model.state.history, sleeps: model.state.sleeps,
                                                   sleepGoalHours: model.settings.sleepGoalHours,
                                                   now: model.now)
        let wakeTimes = InsightsCalculator.wakeTimesByDay(records: model.state.history, days: 14, now: model.now)
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "On-time streak", value: "\(summary.currentStreak) days",
                                 symbol: "flame.fill", tint: .orange)
                        StatTile(title: "Best streak", value: "\(summary.bestStreak) days", symbol: "trophy.fill")
                        StatTile(title: "On time", value: percent(summary.onTimeRate), symbol: "checkmark.seal.fill")
                        StatTile(title: "Time to get up",
                                 value: InsightsCalculator.formatDuration(summary.averageSecondsToWake),
                                 symbol: "timer")
                        StatTile(title: "Avg snoozes", value: String(format: "%.1f", summary.averageSnoozes),
                                 symbol: "zzz")
                        StatTile(title: "Mission time",
                                 value: InsightsCalculator.formatDuration(summary.averageMissionSeconds),
                                 symbol: "figure.walk")
                        StatTile(title: "Wake-up checks",
                                 value: summary.wakeUpCheckPassRate.map(percent) ?? "—",
                                 symbol: "bell.badge.fill")
                        StatTile(title: "Avg sleep",
                                 value: summary.averageSleepHours.map { String(format: "%.1f h", $0) } ?? "—",
                                 symbol: "bed.double.fill", tint: .indigo)
                    }

                    if summary.weeklySleepDebtHours > 0.25 {
                        Card {
                            Label(String(format: "%.1f h of sleep debt this week", summary.weeklySleepDebtHours),
                                  systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Wake-up times · 14 days").font(.headline)
                            if wakeTimes.isEmpty {
                                Text("Your wake-ups will appear here after the first morning.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else {
                                Chart(wakeTimes) { point in
                                    LineMark(x: .value("Day", point.day, unit: .day),
                                             y: .value("Time", point.value))
                                        .foregroundStyle(Theme.accent)
                                    PointMark(x: .value("Day", point.day, unit: .day),
                                              y: .value("Time", point.value))
                                        .foregroundStyle(Theme.accent)
                                }
                                .chartYAxis {
                                    AxisMarks { value in
                                        AxisGridLine()
                                        AxisValueLabel {
                                            if let minutes = value.as(Double.self) {
                                                Text(InsightsCalculator.formatMinutesOfDay(minutes))
                                            }
                                        }
                                    }
                                }
                                .chartYScale(domain: .automatic(includesZero: false))
                                .frame(height: 180)
                            }
                        }
                    }

                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("History").font(.headline)
                            if model.state.history.isEmpty {
                                Text("No wake-ups yet.").foregroundStyle(.secondary)
                            }
                            ForEach(model.state.history.suffix(30).reversed()) { record in
                                HistoryRow(record: record)
                                Divider()
                            }
                        }
                    }

                    if !model.state.history.isEmpty {
                        Button("Clear history", role: .destructive) { confirmClear = true }
                    }
                }
                .padding()
            }
            .navigationTitle("Insights")
            .confirmationDialog("Clear all wake-up history?", isPresented: $confirmClear) {
                Button("Clear history", role: .destructive) { model.clearHistory() }
            }
        }
    }

    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}

struct HistoryRow: View {
    let record: WakeRecord

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: record.isOnTime ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(record.isOnTime ? Color.green : Color.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.dismissedAt.formatted(.dateTime.weekday(.abbreviated).day().month().hour().minute()))
                Text("\(record.alarmLabel) · up in \(InsightsCalculator.formatDuration(record.secondsToWake))"
                     + (record.snoozeCount > 0 ? " · \(record.snoozeCount) snooze" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    ForEach(Array(record.missions.enumerated()), id: \.offset) { _, kind in
                        Image(systemName: kind.symbol)
                    }
                    if record.usedEmergencyExit {
                        Text("Emergency exit").foregroundStyle(.red)
                    }
                    if let passed = record.passedWakeUpCheck {
                        Text(passed ? "Check passed" : "Check missed")
                            .foregroundStyle(passed ? Color.green : Color.orange)
                    }
                }
                .font(.caption2)
            }
        }
    }
}
