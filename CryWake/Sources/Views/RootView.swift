import SwiftUI

enum Theme {
    static let accent = Color(red: 0.98, green: 0.45, blue: 0.55)
    static let night = Color(red: 0.10, green: 0.11, blue: 0.24)
    static let dawn = Color(red: 0.99, green: 0.62, blue: 0.47)
}

struct RootView: View {
    @EnvironmentObject private var engine: AlarmEngine

    var body: some View {
        TabView {
            AlarmListView()
                .tabItem { Label("Alarms", systemImage: "alarm") }
            NavigationStack { VoicePickerView(selection: nil) }
                .tabItem { Label("Voices", systemImage: "waveform") }
            HistoryView()
                .tabItem { Label("Wake-ups", systemImage: "chart.bar") }
        }
        .tint(Theme.accent)
        .safeAreaInset(edge: .top) {
            if let prompt = engine.wakeCheck, engine.ringing == nil {
                WakeCheckBanner(prompt: prompt)
            }
        }
        .fullScreenCover(item: Binding(get: { engine.ringing }, set: { _ in })) { session in
            RingingView(session: session)
                .interactiveDismissDisabled()
        }
    }
}

struct WakeCheckBanner: View {
    @EnvironmentObject private var engine: AlarmEngine
    let prompt: AlarmEngine.WakeCheckPrompt

    var body: some View {
        let remaining = max(0, Int(prompt.deadline.timeIntervalSince(engine.now)))
        HStack(spacing: 12) {
            Image(systemName: "eye.trianglebadge.exclamationmark")
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Still awake?").font(.headline)
                Text("Confirm within \(remaining / 60):\(String(format: "%02d", remaining % 60)) or the baby cries again.")
                    .font(.caption)
            }
            Spacer()
            Button("I'm awake") { engine.confirmAwake() }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("confirmAwake")
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
    }
}
