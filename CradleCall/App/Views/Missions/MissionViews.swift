import SwiftUI

struct MissionHeader: View {
    let kind: MissionKind
    let progress: Int
    let total: Int

    var body: some View {
        VStack(spacing: 8) {
            Label(kind.title, systemImage: kind.symbol)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            ProgressView(value: Double(min(progress, total)), total: Double(max(total, 1)))
                .tint(Theme.accent)
            Text("\(min(progress, total)) / \(total) \(kind.roundsNoun)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Math

struct MathMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @State private var rng = SplitMix64(seed: UInt64.random(in: 0...UInt64.max))
    @State private var problem: MathProblem?
    @State private var input = ""
    @State private var solved = 0
    @State private var wrong = false

    private let keys = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "−", "0", "⌫"]

    var body: some View {
        VStack(spacing: 16) {
            MissionHeader(kind: .math, progress: solved, total: mission.rounds)
            Text(problem?.text ?? "")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(input.isEmpty ? "?" : input)
                .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(wrong ? Color.red : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                ForEach(keys, id: \.self) { key in
                    Button { press(key) } label: {
                        Text(key)
                            .font(.title2.bold())
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button(action: submit) {
                Text("Check")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .onAppear { if problem == nil { next() } }
    }

    private func press(_ key: String) {
        onInteraction()
        wrong = false
        switch key {
        case "⌫": if !input.isEmpty { input.removeLast() }
        case "−": input = input.hasPrefix("-") ? String(input.dropFirst()) : "-" + input
        default: if input.count < 7 { input += key }
        }
    }

    private func submit() {
        onInteraction()
        guard let problem, Int(input) == problem.answer else {
            wrong = true
            return
        }
        solved += 1
        if solved >= mission.rounds { onComplete() } else { next() }
    }

    private func next() {
        problem = MathProblemGenerator.make(mission.difficulty, using: &rng)
        input = ""
    }
}

// MARK: - Typing

struct TypingMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @State private var rng = SplitMix64(seed: UInt64.random(in: 0...UInt64.max))
    @State private var phrase = ""
    @State private var typed = ""
    @State private var done = 0
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MissionHeader(kind: .typing, progress: done, total: mission.rounds)
            Text(phrase)
                .font(.title2.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            TextField("Type the phrase", text: $typed, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focused)
                .onChange(of: typed) { _, _ in
                    onInteraction()
                    if TypingPhrases.matches(typed, target: phrase, difficulty: mission.difficulty) { accept() }
                }
            Text(mission.difficulty >= .hard ? "Capitals and punctuation must match." : "Case doesn't matter.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .onAppear {
            if phrase.isEmpty { phrase = TypingPhrases.pick(mission.difficulty, using: &rng) }
            focused = true
        }
    }

    private func accept() {
        done += 1
        typed = ""
        if done >= mission.rounds { onComplete() } else { phrase = TypingPhrases.pick(mission.difficulty, using: &rng) }
    }
}

// MARK: - Memory

struct MemoryMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @State private var rng = SplitMix64(seed: UInt64.random(in: 0...UInt64.max))
    @State private var board: MemoryBoard?
    @State private var showingPattern = true
    @State private var roundsDone = 0
    @State private var missed: Int?

    var body: some View {
        VStack(spacing: 16) {
            MissionHeader(kind: .memory, progress: roundsDone, total: mission.rounds)
            Text(showingPattern ? "Remember the lit tiles…" : "Tap the tiles that were lit")
                .font(.headline)
            if let board {
                let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: board.side)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(0..<board.cellCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color(for: index, board: board))
                            .aspectRatio(1, contentMode: .fit)
                            .onTapGesture { tap(index) }
                            .accessibilityLabel("Tile \(index + 1)")
                            .accessibilityAddTraits(.isButton)
                    }
                }
            }
            Spacer()
        }
        .onAppear { if board == nil { newRound() } }
    }

    private func color(for index: Int, board: MemoryBoard) -> Color {
        if missed == index { return .red }
        if showingPattern && board.pattern.contains(index) { return Theme.accent }
        if board.found.contains(index) { return Theme.accent.opacity(0.7) }
        return Color.secondary.opacity(0.18)
    }

    private func tap(_ index: Int) {
        guard !showingPattern, var current = board else { return }
        onInteraction()
        switch current.tap(index) {
        case .hit, .alreadyFound:
            board = current
        case .miss:
            missed = index
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { newRound() }
        case .complete:
            board = current
            roundsDone += 1
            if roundsDone >= mission.rounds {
                onComplete()
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { newRound() }
            }
        }
    }

    private func newRound() {
        missed = nil
        board = MemoryBoard.make(mission.difficulty, using: &rng)
        showingPattern = true
        let delay = 1.2 + Double(board?.pattern.count ?? 3) * 0.15
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { showingPattern = false }
    }
}

// MARK: - Shake

struct ShakeMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @StateObject private var motion = MotionService()
    @State private var fallbackTaps = 0
    @State private var finished = false

    private var count: Int { motion.isAvailable ? motion.shakes : fallbackTaps }

    var body: some View {
        VStack(spacing: 20) {
            MissionHeader(kind: .shake, progress: count, total: mission.rounds)
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 90))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.bounce, value: count)
            Text(motion.isAvailable ? "Shake your phone hard!" : "No motion sensor — tap the phone instead.")
                .font(.headline)
            if !motion.isAvailable {
                Button("Tap") { fallbackTaps += 1; event() }
                    .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .onAppear { motion.startShakes(difficulty: mission.difficulty) { event() } }
        .onDisappear { motion.stop() }
    }

    private func event() {
        onInteraction()
        if count >= mission.rounds, !finished {
            finished = true
            motion.stop()
            onComplete()
        }
    }
}

// MARK: - Tap target

struct TapTargetMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @State private var position = CGPoint(x: 0.5, y: 0.5)
    @State private var hits = 0

    private var diameter: CGFloat {
        switch mission.difficulty {
        case .easy: return 90
        case .medium: return 70
        case .hard: return 52
        case .extreme: return 40
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            MissionHeader(kind: .tapTarget, progress: hits, total: mission.rounds)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.secondary.opacity(0.08))
                        .onTapGesture { onInteraction() }
                    Text("👶")
                        .font(.system(size: diameter * 0.6))
                        .frame(width: diameter, height: diameter)
                        .background(Theme.warm, in: Circle())
                        .position(x: diameter / 2 + position.x * max(geo.size.width - diameter, 1),
                                  y: diameter / 2 + position.y * max(geo.size.height - diameter, 1))
                        .onTapGesture { hit() }
                        .accessibilityLabel("Target")
                        .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    private func hit() {
        onInteraction()
        hits += 1
        if hits >= mission.rounds {
            onComplete()
            return
        }
        withAnimation(.spring(duration: 0.25)) {
            position = CGPoint(x: .random(in: 0...1), y: .random(in: 0...1))
        }
    }
}

// MARK: - Steps

struct StepsMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @StateObject private var motion = MotionService()
    @State private var finished = false

    var body: some View {
        VStack(spacing: 20) {
            MissionHeader(kind: .steps, progress: motion.steps, total: mission.rounds)
            Image(systemName: "figure.walk.motion")
                .font(.system(size: 90))
                .foregroundStyle(Theme.accent)
                .symbolEffect(.pulse)
            Text(motion.isAvailable ? "Get out of bed and walk around." : "Step counting isn't available on this device.")
                .font(.headline)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .onAppear {
            motion.startSteps {
                onInteraction()
                if motion.steps >= mission.rounds, !finished {
                    finished = true
                    motion.stop()
                    onComplete()
                }
            }
        }
        .onDisappear { motion.stop() }
    }
}

// MARK: - Barcode

struct BarcodeMissionView: View {
    let mission: MissionConfig
    let onInteraction: () -> Void
    let onComplete: () -> Void
    @State private var message = "Scan your registered barcode."
    @State private var finished = false

    var body: some View {
        VStack(spacing: 12) {
            MissionHeader(kind: .barcode, progress: finished ? 1 : 0, total: 1)
            BarcodeScannerView { code in
                onInteraction()
                guard !finished else { return }
                if code == mission.barcodeValue {
                    finished = true
                    onComplete()
                } else {
                    message = "That's a different code. Find the one you registered!"
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            Text(message).font(.headline).multilineTextAlignment(.center)
        }
    }
}
