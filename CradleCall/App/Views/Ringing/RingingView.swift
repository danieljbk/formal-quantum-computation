import SwiftUI

/// Full-screen alarm: the baby is crying until the missions are done.
struct RingingView: View {
    @Environment(AppModel.self) private var model
    @State private var inMission = false
    @State private var wobble = false

    var body: some View {
        ZStack {
            Theme.ringingGradient.ignoresSafeArea()
            if let ring = model.currentRing {
                if inMission && !ring.alarm.missions.isEmpty {
                    MissionRunnerView(ring: ring)
                } else {
                    idle(ring)
                }
            }
        }
        .interactiveDismissDisabled()
        .onChange(of: model.currentRing?.id) { _, _ in inMission = false }
    }

    private func idle(_ ring: RingSession) -> some View {
        VStack(spacing: 20) {
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 76, weight: .thin, design: .rounded))
                    .monospacedDigit()
            }
            Text(ring.alarm.label)
                .font(.title2.weight(.semibold))
            if ring.reason == .wakeUpCheckFailed {
                Text("You didn't confirm you were awake!")
                    .font(.headline)
                    .padding(8)
                    .background(.white.opacity(0.25), in: Capsule())
            }

            Text("😭")
                .font(.system(size: 120))
                .rotationEffect(.degrees(wobble ? 8 : -8))
                .scaleEffect(wobble ? 1.06 : 0.96)
                .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: wobble)
                .onAppear { wobble = true }
                .accessibilityLabel("Crying baby")

            Label(model.voice(id: ring.alarm.voiceID).name + " is crying", systemImage: "waveform")
                .font(.headline)
            Spacer()

            Button {
                if ring.alarm.missions.isEmpty {
                    model.completeMission()
                } else {
                    model.missionActivity()
                    inMission = true
                }
            } label: {
                Text(ring.alarm.missions.isEmpty ? "I'm up" : "Soothe the baby")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white, in: Capsule())
                    .foregroundStyle(Theme.accent)
            }

            if model.canSnooze() {
                Button {
                    model.snooze()
                } label: {
                    Text(snoozeTitle(ring))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white.opacity(0.25), in: Capsule())
                }
            } else if ring.alarm.snooze.isEnabled {
                Text("No snoozes left").font(.footnote.bold()).opacity(0.8)
            }
            if ring.reason == .preview {
                Text("Preview — snoozing or finishing won't be recorded.")
                    .font(.footnote)
                    .opacity(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(24)
    }

    private func snoozeTitle(_ ring: RingSession) -> String {
        let minutes = ring.alarm.snooze.minutes
        if let left = SnoozePolicy.remaining(ring.alarm.snooze, used: ring.snoozeCount) {
            return "Snooze \(minutes) min · \(left) left"
        }
        return "Snooze \(minutes) min"
    }
}

/// Runs the alarm's missions one after another, resetting on inactivity.
struct MissionRunnerView: View {
    @Environment(AppModel.self) private var model
    let ring: RingSession
    @State private var index = 0
    @State private var resetToken = 0
    @State private var guardTimer: InactivityGuard?
    @State private var secondsLeft = 0
    @State private var showReset = false
    @State private var showEmergency = false
    private let clock = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    private var timeout: TimeInterval { TimeInterval(model.settings.antiCheat.inactivityResetSeconds) }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Mission \(min(index + 1, ring.alarm.missions.count)) of \(ring.alarm.missions.count)")
                    .font(.headline)
                Spacer()
                Label("\(secondsLeft)s", systemImage: "timer")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(secondsLeft <= 5 ? Color.yellow : Color.white)
                    .accessibilityLabel("\(secondsLeft) seconds before the baby cries louder")
            }
            .foregroundStyle(.white)

            if showReset {
                Text("Too slow! The baby is crying again — start over.")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            }

            if index < ring.alarm.missions.count {
                let mission = ring.alarm.missions[index]
                VStack {
                    MissionContentView(mission: mission, resetToken: resetToken,
                                       onInteraction: interacted) {
                        advance()
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }

            Button("Can't do it? Emergency exit") { showEmergency = true }
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding()
        .onAppear {
            guardTimer = InactivityGuard(timeout: timeout, now: Date())
            secondsLeft = Int(timeout)
        }
        .onReceive(clock) { now in
            guard var guardState = guardTimer else { return }
            secondsLeft = guardState.secondsRemaining(at: now)
            if guardState.isExpired(at: now) {
                resetToken += 1
                showReset = true
                model.missionWentIdle()
                guardState.noteInteraction(at: now)
                guardTimer = guardState
            }
        }
        .sheet(isPresented: $showEmergency) {
            EmergencyExitView(repeats: model.settings.antiCheat.emergencyPhraseRepeats,
                              onInteraction: interacted) {
                showEmergency = false
                model.completeMission(usedEmergencyExit: true)
            }
            .interactiveDismissDisabled()
        }
    }

    private func interacted() {
        guardTimer?.noteInteraction(at: Date())
        showReset = false
        model.missionActivity()
    }

    private func advance() {
        interacted()
        if index + 1 >= ring.alarm.missions.count {
            model.completeMission()
        } else {
            index += 1
            resetToken += 1
        }
    }
}

/// Dispatches to the view for one mission kind.
struct MissionContentView: View {
    let mission: MissionConfig
    let resetToken: Int
    let onInteraction: () -> Void
    let onComplete: () -> Void

    var body: some View {
        Group {
            switch mission.kind {
            case .math:
                MathMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            case .typing:
                TypingMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            case .memory:
                MemoryMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            case .shake:
                ShakeMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            case .tapTarget:
                TapTargetMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            case .steps:
                StepsMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            case .barcode:
                BarcodeMissionView(mission: mission, onInteraction: onInteraction, onComplete: onComplete)
            }
        }
        .id("\(mission.id)-\(resetToken)")
    }
}

/// Type a long phrase several times to give up on a mission. Logged in the history.
struct EmergencyExitView: View {
    static let phrase = "I am giving up on my mission and getting out of bed"
    let repeats: Int
    let onInteraction: () -> Void
    let onExit: () -> Void
    @State private var typed = ""
    @State private var done = 0

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Type this exactly \(repeats) times. Emergency exits show up in your insights.")
                    .foregroundStyle(.secondary)
                Text(Self.phrase).font(.title3.bold())
                TextField("Type here", text: $typed, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: typed) { _, _ in onInteraction() }
                    .onSubmit(check)
                Button("Submit", action: check).buttonStyle(.borderedProminent)
                ProgressView(value: Double(done), total: Double(max(repeats, 1)))
                Spacer()
            }
            .padding()
            .navigationTitle("Emergency exit")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func check() {
        guard TypingPhrases.matches(typed, target: Self.phrase, difficulty: .hard) else { return }
        done += 1
        typed = ""
        if done >= repeats { onExit() }
    }
}

/// "Are you still awake?" — confirm or the crying comes back.
struct WakeUpCheckView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            Theme.nightGradient.ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("🍼").font(.system(size: 96))
                Text("Are you still awake?")
                    .font(.largeTitle.bold())
                if let plan = model.pendingWakeUpCheck {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let left = max(0, Int(plan.deadline.timeIntervalSince(context.date)))
                        Text("The baby starts crying again in \(left) s")
                            .font(.headline.monospacedDigit())
                    }
                }
                Spacer()
                Button {
                    model.confirmAwake()
                } label: {
                    Text("I'm awake")
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.warm, in: Capsule())
                        .foregroundStyle(Theme.night)
                }
            }
            .foregroundStyle(.white)
            .padding(24)
        }
    }
}
