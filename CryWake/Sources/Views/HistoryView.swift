import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AlarmStore
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                let stats = store.stats
                Section {
                    HStack(spacing: 12) {
                        StatTile(value: "\(stats.total)", caption: "Wake-ups")
                        StatTile(value: String(format: "%.1f", stats.averageSnoozes), caption: "Avg snoozes")
                        StatTile(value: "\(stats.cleanStreak)", caption: "Clean streak")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    if stats.total > 0 {
                        Text("On average the baby cried for \(String(format: "%.1f", stats.averageMinutesToDismiss)) min before you soothed it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("History") {
                    if store.history.isEmpty {
                        Text("Your wake-ups will show up here.").foregroundStyle(.secondary)
                    }
                    ForEach(store.history) { record in
                        WakeRecordRow(record: record)
                    }
                }
            }
            .navigationTitle("Wake-ups")
            .toolbar {
                if !store.history.isEmpty {
                    Button("Clear") { confirmClear = true }
                }
            }
            .confirmationDialog("Clear all wake-up history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { store.clearHistory() }
            }
        }
    }
}

struct StatTile: View {
    let value: String
    let caption: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title.bold()).monospacedDigit()
            Text(caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct WakeRecordRow: View {
    let record: WakeRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(record.dismissedAt.formatted(.dateTime.weekday(.abbreviated).month().day().hour().minute()))
                    .font(.headline)
                Spacer()
                checkBadge
            }
            HStack(spacing: 10) {
                Text(record.alarmLabel)
                Text("\(record.snoozeCount) snooze\(record.snoozeCount == 1 ? "" : "s")")
                if record.mission != .none {
                    Label(record.mission.title, systemImage: record.mission.systemImage)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var checkBadge: some View {
        switch record.wakeCheck {
        case .notRequired: EmptyView()
        case .pending: Image(systemName: "hourglass").foregroundStyle(.orange)
        case .passed: Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.seal.fill").foregroundStyle(.red)
        }
    }
}
