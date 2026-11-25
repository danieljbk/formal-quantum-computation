import SwiftUI

struct RingingView: View {
    @EnvironmentObject private var engine: AlarmEngine
    let session: AlarmEngine.RingingSession
    @State private var missionStarted = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [Theme.night, Theme.dawn], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            if missionStarted && session.alarm.mission != .none {
                MissionRunner(kind: session.alarm.mission,
                              difficulty: session.alarm.missionDifficulty,
                              rounds: session.alarm.missionRounds) {
                    engine.soothe()
                }
                .padding()
            } else {
                crying
            }
        }
        .foregroundStyle(.white)
    }

    private var crying: some View {
        VStack(spacing: 18) {
            Spacer()
            Text(engine.now.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 64, weight: .thin, design: .rounded))
                .monospacedDigit()
            Text("\u{1F62D}")
                .font(.system(size: 110))
                .scaleEffect(pulse ? 1.12 : 0.94)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }
            Text("\(session.voice?.name ?? "Your baby") is crying!")
                .font(.title.bold())
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.headline)
                .opacity(0.85)
                .multilineTextAlignment(.center)
            Spacer()

            Button {
                if session.alarm.mission == .none { engine.soothe() } else { missionStarted = true }
            } label: {
                Label(session.alarm.mission == .none ? "Soothe the baby" : "Soothe: \(session.alarm.mission.title)",
                      systemImage: "heart.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent, in: Capsule())
            }
            .accessibilityIdentifier("soothe")

            if session.canSnooze {
                Button {
                    engine.snooze()
                } label: {
                    Text(snoozeTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.18), in: Capsule())
                }
                .accessibilityIdentifier("snooze")
            }
        }
        .padding(28)
    }

    private var subtitle: String {
        switch session.reason {
        case .scheduled: return session.isTest ? "This is what your alarm sounds like." : session.alarm.displayLabel
        case .snooze: return "Snooze is over \u{2014} \(session.alarm.displayLabel)"
        case .wakeCheck: return "You didn't confirm you were awake!"
        }
    }

    private var snoozeTitle: String {
        let a = session.alarm
        var t = "Snooze \(a.snoozeMinutes) min"
        if let max = a.maxSnoozes { t += " (\(max - session.snoozeCount) left)" }
        return t
    }
}
