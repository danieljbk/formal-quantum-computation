import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        TabView {
            AlarmListView()
                .tabItem { Label("Alarms", systemImage: "alarm.fill") }
            SleepView()
                .tabItem { Label("Sleep", systemImage: "moon.zzz.fill") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
            NavigationStack { BriefingView(isPresentedAfterWake: false) }
                .tabItem { Label("Today", systemImage: "sun.horizon.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.accent)
        .fullScreenCover(item: overlayBinding) { overlay in
            switch overlay {
            case .ringing:
                RingingView()
            case .wakeUpCheck:
                WakeUpCheckView()
            case .briefing:
                NavigationStack { BriefingView(isPresentedAfterWake: true) }
            }
        }
    }

    private var overlayBinding: Binding<Overlay?> {
        Binding(get: { model.overlay }, set: { model.overlay = $0 })
    }
}

enum Theme {
    static let accent = Color(red: 0.93, green: 0.36, blue: 0.52)
    static let warm = Color(red: 1.0, green: 0.72, blue: 0.55)
    static let night = Color(red: 0.12, green: 0.11, blue: 0.25)
    static let ringingGradient = LinearGradient(colors: [Color(red: 0.98, green: 0.45, blue: 0.55),
                                                         Color(red: 0.99, green: 0.69, blue: 0.47)],
                                                startPoint: .top, endPoint: .bottom)
    static let nightGradient = LinearGradient(colors: [night, Color(red: 0.27, green: 0.2, blue: 0.45)],
                                              startPoint: .top, endPoint: .bottom)
}

/// Rounded tile used across the app.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct StatTile: View {
    var title: String
    var value: String
    var symbol: String
    var tint: Color = Theme.accent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(tint)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
