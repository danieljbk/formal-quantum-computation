import CoreMotion
import SwiftUI
import UIKit

struct RingingView: View {
    @EnvironmentObject private var engine: AlarmEngine
    let session: RingingSession
    @State private var inMission = false

    var body: some View {
        ZStack {
            Theme.ringingGradient.ignoresSafeArea()
            if inMission {
                MissionView(settings: session.alarm.mission,
                            onComplete: { engine.dismiss() },
                            onBack: { inMission = false })
                    .padding()
            } else {
                ringing
            }
        }
        .foregroundColor(.white)
        .onChange(of: inMission) { active in
            AudioService.shared.duck(active)
        }
        .interactiveDismissDisabled()
    }

    private var ringing: some View {
        VStack(spacing: 18) {
            Spacer()
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(context.date.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 72, weight: .thin, design: .rounded))
                    .monospacedDigit()
            }
            Text(session.alarm.displayLabel)
                .font(.title3.weight(.medium))
            CryingBaby(emoji: session.voice.emoji)
                .padding(.vertical, 10)
            Text("\(session.voice.displayName) baby is crying!")
                .font(.title2.weight(.bold))
            if session.snoozeCount > 0 {
                Text("Snoozed \(session.snoozeCount)×")
                    .font(.footnote)
                    .opacity(0.8)
            }
            Spacer()
            VStack(spacing: 12) {
                if session.canSnooze {
                    PillButton(title: "Snooze \(session.alarm.snooze.minutes) min", systemImage: "zzz", filled: false) {
                        engine.snooze()
                    }
                }
                if let left = session.snoozesLeftText {
                    Text(left).font(.footnote).opacity(0.8)
                }
                PillButton(title: session.alarm.mission.kind == .none
                           ? "I'm up – calm the baby"
                           : "Calm the baby (\(session.alarm.mission.kind.title.lowercased()) mission)",
                           systemImage: "sun.max.fill") {
                    if session.alarm.mission.kind == .none {
                        engine.dismiss()
                    } else {
                        inMission = true
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
}

struct MissionView: View {
    @State private var session: MissionSession
    let onComplete: () -> Void
    let onBack: () -> Void

    @State private var answer = ""
    @State private var wrong = false
    @FocusState private var focused: Bool
    @StateObject private var motion = ShakeMonitor()

    init(settings: MissionSettings, onComplete: @escaping () -> Void, onBack: @escaping () -> Void) {
        _session = State(initialValue: MissionSession(settings: settings))
        self.onComplete = onComplete
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: onBack) {
                    Label("Back", systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
                Text("\(session.completed) / \(session.required)")
                    .monospacedDigit()
                    .font(.headline)
            }
            ProgressView(value: session.progress)
                .tint(.white)
            Spacer()
            content
            Spacer()
        }
        .onChange(of: session.completed) { _ in
            if session.isComplete { onComplete() }
        }
        .onAppear {
            if session.settings.kind == .shake {
                motion.start { session.registerAction() }
            }
            focused = true
        }
        .onDisappear { motion.stop() }
    }

    @ViewBuilder
    private var content: some View {
        switch session.settings.kind {
        case .math:
            VStack(spacing: 20) {
                Text("Solve to calm the baby")
                    .font(.headline)
                Text("\(session.problem?.prompt ?? "") = ?")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .offset(x: wrong ? -10 : 0)
                TextField("Answer", text: $answer)
                    .keyboardType(.numberPad)
                    .font(.title.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                PillButton(title: "Submit", systemImage: "checkmark") { submit() }
            }
        case .typing:
            VStack(spacing: 20) {
                Text("Type this sentence exactly")
                    .font(.headline)
                Text(session.phrase ?? "")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.white.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                TextField("Start typing…", text: $answer, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .focused($focused)
                    .onChange(of: answer) { text in
                        if let phrase = session.phrase, TypingPhrases.matches(text, phrase) {
                            session.submit(text)
                            answer = ""
                        }
                    }
            }
        case .shake:
            VStack(spacing: 16) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 90))
                Text("Shake your phone to rock the baby")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Text("\(max(0, session.required - session.completed)) shakes to go")
                    .font(.headline)
                    .opacity(0.85)
            }
        case .tap:
            VStack(spacing: 16) {
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    session.registerAction()
                } label: {
                    Text("👶")
                        .font(.system(size: 110))
                        .frame(width: 220, height: 220)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Pat the baby")
                Text("Pat the baby \(max(0, session.required - session.completed)) more times")
                    .font(.headline)
            }
        case .none:
            PillButton(title: "I'm up") { onComplete() }
        }
    }

    private func submit() {
        if session.submit(answer) {
            answer = ""
        } else {
            answer = ""
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            withAnimation(.default.repeatCount(3, autoreverses: true).speed(4)) { wrong = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { wrong = false }
        }
    }
}

/// Feeds Core Motion user-acceleration samples into `ShakeDetector`.
final class ShakeMonitor: ObservableObject {
    private let manager = CMMotionManager()
    private var detector = ShakeDetector()

    func start(onShake: @escaping () -> Void) {
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 50.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let a = data?.userAcceleration else { return }
            if self.detector.ingest(x: a.x, y: a.y, z: a.z, at: data?.timestamp ?? 0) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onShake()
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}

struct WakeCheckView: View {
    @EnvironmentObject private var engine: AlarmEngine
    let check: WakeCheckSession

    var body: some View {
        ZStack {
            Theme.headerGradient.ignoresSafeArea()
            VStack(spacing: 24) {
                Spacer()
                Text("☀️").font(.system(size: 110))
                Text("Are you awake?")
                    .font(.largeTitle.weight(.bold))
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let left = max(0, Int(check.deadline.timeIntervalSince(context.date).rounded(.up)))
                    Text("Confirm within \(left) s or the baby starts crying again.")
                        .multilineTextAlignment(.center)
                        .monospacedDigit()
                        .opacity(0.9)
                }
                Spacer()
                PillButton(title: "I'm awake", systemImage: "checkmark.circle.fill") {
                    engine.confirmAwake()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .padding()
        }
        .foregroundColor(.white)
        .interactiveDismissDisabled()
    }
}
