import SwiftUI

/// Runs `rounds` rounds of a mission, then calls `onComplete`.
struct MissionRunner: View {
    let kind: MissionKind
    let difficulty: MissionDifficulty
    let rounds: Int
    let onComplete: () -> Void

    @State private var round = 1

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Label(kind.title, systemImage: kind.systemImage).font(.headline)
                Spacer()
                Text("Round \(round) of \(rounds)").font(.subheadline.monospacedDigit())
            }
            Group {
                switch kind {
                case .none: EmptyView()
                case .math: MathMissionView(difficulty: difficulty, onSolved: advance)
                case .shake: ShakeMissionView(target: MissionTargets.shakes(difficulty), onSolved: advance)
                case .typing: TypingMissionView(difficulty: difficulty, onSolved: advance)
                case .tap: TapMissionView(target: MissionTargets.taps(difficulty), onSolved: advance)
                }
            }
            .id(round) // fresh state each round
            Spacer()
        }
        .onAppear { if kind == .none { onComplete() } }
    }

    private func advance() {
        if round >= rounds { onComplete() } else { round += 1 }
    }
}

struct MathMissionView: View {
    let difficulty: MissionDifficulty
    let onSolved: () -> Void

    @State private var problem: MathProblem
    @State private var input = ""
    @State private var wrong = false
    @FocusState private var focused: Bool

    init(difficulty: MissionDifficulty, onSolved: @escaping () -> Void) {
        self.difficulty = difficulty
        self.onSolved = onSolved
        var rng = SystemRandomNumberGenerator()
        _problem = State(initialValue: MathProblem.generate(difficulty, using: &rng))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(problem.text + " = ?")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
            TextField("Answer", text: $input)
                .keyboardType(.numberPad)
                .font(.title.monospacedDigit())
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                .focused($focused)
                .accessibilityIdentifier("mathAnswer")
            if wrong {
                Text("Not quite \u{2014} the baby is still crying. New problem!")
                    .font(.subheadline)
            }
            Button("Submit") { submit() }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Theme.accent, in: Capsule())
                .accessibilityIdentifier("mathSubmit")
        }
        .onAppear { focused = true }
    }

    private func submit() {
        if problem.check(input) {
            onSolved()
        } else {
            wrong = true
            input = ""
            var rng = SystemRandomNumberGenerator()
            problem = MathProblem.generate(difficulty, using: &rng)
        }
    }
}

struct ShakeMissionView: View {
    let target: Int
    let onSolved: () -> Void
    @StateObject private var detector = ShakeDetector()
    @State private var done = false

    var body: some View {
        VStack(spacing: 16) {
            Text("\u{1F476}").font(.system(size: 90))
                .rotationEffect(.degrees(detector.count.isMultiple(of: 2) ? -8 : 8))
                .animation(.spring(response: 0.2), value: detector.count)
            Text("Rock the baby: shake your phone")
                .font(.title3.bold())
            ProgressView(value: Double(min(detector.count, target)), total: Double(target))
                .tint(.white)
            Text("\(min(detector.count, target)) / \(target)")
                .font(.title.monospacedDigit())
            if !detector.isAvailable {
                Button("Shake (no motion sensor)") { detector.registerManualShake() }
                    .buttonStyle(.bordered)
            }
        }
        .onAppear { detector.start() }
        .onDisappear { detector.stop() }
        .onChange(of: detector.count) { count in
            if count >= target && !done {
                done = true
                onSolved()
            }
        }
    }
}

struct TypingMissionView: View {
    let difficulty: MissionDifficulty
    let onSolved: () -> Void

    @State private var line: String
    @State private var input = ""
    @State private var done = false

    init(difficulty: MissionDifficulty, onSolved: @escaping () -> Void) {
        self.difficulty = difficulty
        self.onSolved = onSolved
        var rng = SystemRandomNumberGenerator()
        _line = State(initialValue: MissionTargets.lullabyLine(difficulty, using: &rng))
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Sing it back to the baby:").font(.headline)
            Text(line)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            TextField("Type the line exactly", text: $input, axis: .vertical)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                .accessibilityIdentifier("typingInput")
            Text(MissionTargets.typingMatches(input, target: line) ? "Perfect!" : "Keep typing\u{2026}")
                .font(.subheadline)
        }
        .onChange(of: input) { value in
            if !done && MissionTargets.typingMatches(value, target: line) {
                done = true
                onSolved()
            }
        }
    }
}

struct TapMissionView: View {
    let target: Int
    let onSolved: () -> Void
    @State private var taps = 0

    var body: some View {
        VStack(spacing: 16) {
            Text("Pat the baby \(target) times").font(.title3.bold())
            Button {
                guard taps < target else { return }
                taps += 1
                if taps == target { onSolved() }
            } label: {
                Text("\u{1F476}")
                    .font(.system(size: 110))
                    .frame(width: 220, height: 220)
                    .background(Color.white.opacity(0.15), in: Circle())
                    .scaleEffect(taps.isMultiple(of: 2) ? 1 : 0.95)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("patBaby")
            ProgressView(value: Double(taps), total: Double(target)).tint(.white)
            Text("\(taps) / \(target)").font(.title.monospacedDigit())
        }
    }
}
