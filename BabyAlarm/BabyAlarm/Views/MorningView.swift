import SwiftUI

/// Morning tab: the same briefing that appears right after an alarm is dismissed.
struct MorningView: View {
    var body: some View {
        NavigationStack {
            BriefingContent(showsHeader: false)
                .navigationTitle("Morning")
        }
    }
}

/// Weather, quote, fortune, last night's sleep and today's alarms.
struct BriefingContent: View {
    let showsHeader: Bool
    @EnvironmentObject private var settings: AppSettingsStore
    @EnvironmentObject private var engine: AlarmEngine
    @EnvironmentObject private var sleep: SleepService
    @StateObject private var weather = WeatherService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TimelineView(.periodic(from: .now, by: 60)) { ctx in
                    VStack(alignment: .leading, spacing: 4) {
                        if showsHeader {
                            Text("You calmed the baby! 🍼").font(.headline).opacity(0.9)
                        }
                        Text(MorningContent.greeting(for: ctx.date))
                            .font(.largeTitle.weight(.bold))
                        Text(ctx.date.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .opacity(0.85)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(LinearGradient(colors: [Theme.pink, Color.orange.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                }

                if settings.prefs.briefingWeather {
                    card(title: "Weather", symbol: "cloud.sun.fill") {
                        if let w = weather.report {
                            HStack(alignment: .center, spacing: 14) {
                                Text(w.emoji).font(.system(size: 46))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(Int(w.temperature.rounded()))° · \(w.summary)").font(.title3.weight(.semibold))
                                    Text(detailLine(w))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        } else {
                            Text(weather.status).foregroundColor(.secondary)
                        }
                        Text("Weather data by Open-Meteo.com").font(.caption2).foregroundColor(.secondary)
                    }
                }

                card(title: "Quote of the day", symbol: "quote.opening") {
                    let q = MorningContent.quote(for: Date())
                    Text("“\(q.text)”").font(.body.italic())
                    Text("— \(q.author)").font(.caption).foregroundColor(.secondary)
                }

                card(title: "\(settings.prefs.zodiac.symbol) \(settings.prefs.zodiac.title) fortune", symbol: "sparkles") {
                    Text(MorningContent.fortune(for: settings.prefs.zodiac, on: Date()))
                    Text("Just for fun. Change your sign in Settings.").font(.caption2).foregroundColor(.secondary)
                }

                if let last = sleep.sessions.first {
                    card(title: "Last night", symbol: "bed.double.fill") {
                        Text("Slept \(durationText(last.duration)), \(last.events.count) sound event\(last.events.count == 1 ? "" : "s") recorded")
                    }
                }

                card(title: "Today's alarms", symbol: "alarm.fill") {
                    let today = upcomingToday()
                    if today.isEmpty {
                        Text("No more alarms today.").foregroundColor(.secondary)
                    }
                    ForEach(today) { item in
                        HStack {
                            Text(item.date.formatted(date: .omitted, time: .shortened)).monospacedDigit().font(.headline)
                            Text(item.alarm.displayLabel).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onAppear {
            if settings.prefs.briefingWeather { weather.refresh() }
        }
        .refreshable {
            if settings.prefs.briefingWeather { weather.refresh(force: true) }
        }
    }

    private struct TodayAlarm: Identifiable {
        let alarm: Alarm
        let date: Date
        var id: UUID { alarm.id }
    }

    private func upcomingToday() -> [TodayAlarm] {
        let now = Date()
        let end = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)
        var result: [TodayAlarm] = []
        for alarm in engine.alarms {
            if let date = AlarmSchedule.nextFireDate(for: alarm, after: now), date < end {
                result.append(TodayAlarm(alarm: alarm, date: date))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    private func detailLine(_ w: WeatherReport) -> String {
        var line = "High \(Int(w.high.rounded()))°  Low \(Int(w.low.rounded()))°"
        if let rain = w.precipitationChance { line += "  ·  \(rain)% rain" }
        return line
    }

    private func card<Content: View>(title: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.subheadline.weight(.semibold)).foregroundColor(Theme.lilac)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
