import SwiftUI

/// The morning briefing shown after waking (and in the Today tab).
struct BriefingView: View {
    @Environment(AppModel.self) private var model
    @StateObject private var service = BriefingService()
    let isPresentedAfterWake: Bool

    private var lastNight: SleepSession? {
        model.state.sleeps.filter { $0.end != nil }.max { ($0.end ?? .distantPast) < ($1.end ?? .distantPast) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BriefingService.greeting(for: model.now))
                        .font(.largeTitle.bold())
                    Text(model.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                weatherCard

                if let lastNight, let duration = lastNight.duration {
                    Card {
                        HStack {
                            Image(systemName: "bed.double.fill").font(.title).foregroundStyle(.indigo)
                            VStack(alignment: .leading) {
                                Text("Last sleep").font(.headline)
                                Text("\(InsightsCalculator.formatDuration(duration)) · goal "
                                     + String(format: "%.1f h", model.settings.sleepGoalHours))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                calendarCard

                if let next = model.nextRing {
                    Card {
                        HStack {
                            Image(systemName: "alarm.fill").font(.title).foregroundStyle(Theme.accent)
                            VStack(alignment: .leading) {
                                Text("Next alarm").font(.headline)
                                Text("\(next.date.formatted(.dateTime.weekday(.abbreviated).hour().minute())) · "
                                     + next.alarm.label)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Card {
                    Label(BriefingService.quote(for: model.now), systemImage: "quote.opening")
                        .font(.body.italic())
                }
            }
            .padding()
        }
        .navigationTitle(isPresentedAfterWake ? "Briefing" : "Today")
        .navigationBarTitleDisplayMode(isPresentedAfterWake ? .inline : .large)
        .toolbar {
            if isPresentedAfterWake {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start my day") { model.overlay = nil }.bold()
                }
            }
        }
        .refreshable { await service.refresh(settings: model.settings) }
        .task { await service.refresh(settings: model.settings) }
    }

    @ViewBuilder
    private var weatherCard: some View {
        if model.settings.briefingUsesLocation {
            Card {
                if let weather = service.weather {
                    HStack(spacing: 16) {
                        Image(systemName: weather.symbol)
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 44))
                        VStack(alignment: .leading) {
                            Text("\(Int(weather.temperature.rounded()))° · \(weather.description)")
                                .font(.title3.bold())
                            Text("High \(Int(weather.high.rounded()))°  Low \(Int(weather.low.rounded()))°  "
                                 + "Rain \(weather.precipitationChance)%")
                                .foregroundStyle(.secondary)
                        }
                    }
                } else if let error = service.weatherError {
                    Label(error, systemImage: "location.slash").foregroundStyle(.secondary)
                } else {
                    HStack { ProgressView(); Text("Checking the weather…").foregroundStyle(.secondary) }
                }
            }
        }
    }

    @ViewBuilder
    private var calendarCard: some View {
        if model.settings.briefingUsesCalendar {
            Card {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's plans").font(.headline)
                    if let error = service.calendarError {
                        Text(error).foregroundStyle(.secondary)
                    } else if service.events.isEmpty {
                        Text(service.isLoading ? "Loading…" : "Nothing on the calendar. Enjoy!")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(service.events) { event in
                        HStack {
                            Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(Theme.accent)
                                .frame(width: 80, alignment: .leading)
                            Text(event.title)
                        }
                    }
                }
            }
        }
    }
}
