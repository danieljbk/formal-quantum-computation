import Foundation

struct MathProblem: Equatable {
    let prompt: String
    let answer: Int

    static func make<G: RandomNumberGenerator>(_ difficulty: MathDifficulty, using rng: inout G) -> MathProblem {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 10...49, using: &rng)
            let b = Int.random(in: 10...49, using: &rng)
            return MathProblem(prompt: "\(a) + \(b)", answer: a + b)
        case .medium:
            let a = Int.random(in: 11...29, using: &rng)
            let b = Int.random(in: 3...9, using: &rng)
            let c = Int.random(in: 10...99, using: &rng)
            return MathProblem(prompt: "\(a) × \(b) + \(c)", answer: a * b + c)
        case .hard:
            let a = Int.random(in: 12...49, using: &rng)
            let b = Int.random(in: 6...9, using: &rng)
            let c = Int.random(in: 12...49, using: &rng)
            let d = Int.random(in: 3...9, using: &rng)
            return MathProblem(prompt: "\(a) × \(b) + \(c) × \(d)", answer: a * b + c * d)
        }
    }
}

enum TypingPhrases {
    static let all = [
        "I am awake and the baby can stop crying",
        "Good morning, today is going to be a great day",
        "I will get out of bed right now",
        "Rise and shine, the little one needs me",
        "No more snoozing, I am up",
        "Coffee first, then everything else",
        "I am grateful for this brand new morning",
    ]

    static func normalized(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func matches(_ typed: String, _ target: String) -> Bool {
        let t = normalized(target)
        return !t.isEmpty && normalized(typed) == t
    }
}

/// Counts shakes from accelerometer samples (user acceleration in g, gravity removed).
struct ShakeDetector {
    var threshold: Double = 1.4
    var minInterval: TimeInterval = 0.25
    private(set) var lastShake: TimeInterval = -.infinity
    private var armed = true

    init(threshold: Double = 1.4, minInterval: TimeInterval = 0.25) {
        self.threshold = threshold
        self.minInterval = minInterval
    }

    /// Returns true when this sample completes a new shake.
    mutating func ingest(x: Double, y: Double, z: Double, at time: TimeInterval) -> Bool {
        let magnitude = (x * x + y * y + z * z).squareRoot()
        if magnitude < threshold * 0.5 { armed = true }
        guard armed, magnitude >= threshold, time - lastShake >= minInterval else { return false }
        armed = false
        lastShake = time
        return true
    }
}

/// State of one in-progress dismissal mission.
struct MissionSession {
    let settings: MissionSettings
    private(set) var completed: Int = 0
    private(set) var problem: MathProblem?
    private(set) var phrase: String?
    private(set) var memory: MemoryPuzzle?
    private(set) var mistakes: Int = 0
    private var rng: SystemRandomNumberGeneratorBox

    init(settings: MissionSettings) {
        self.init(settings: settings, rng: SystemRandomNumberGenerator())
    }

    init<G: RandomNumberGenerator>(settings: MissionSettings, rng: G) {
        var s = settings
        if s.kind != .none { s.rounds = min(max(s.rounds, s.kind.roundsRange.lowerBound), s.kind.roundsRange.upperBound) }
        self.settings = s
        self.rng = SystemRandomNumberGeneratorBox(rng)
        advance()
    }

    var required: Int { settings.kind == .none ? 0 : settings.rounds }
    var isComplete: Bool { completed >= required }
    var progress: Double { required == 0 ? 1 : Double(completed) / Double(required) }

    /// Math or typing answer. Returns true if accepted.
    @discardableResult
    mutating func submit(_ text: String) -> Bool {
        guard !isComplete else { return true }
        let ok: Bool
        switch settings.kind {
        case .math:
            let digits = text.trimmingCharacters(in: .whitespacesAndNewlines)
            ok = Int(digits) == problem?.answer
        case .typing:
            ok = phrase.map { TypingPhrases.matches(text, $0) } ?? false
        case .barcode:
            ok = BarcodeMatcher.matches(scanned: text, registered: settings.barcodePayload)
        default:
            ok = false
        }
        if ok { completed += 1; advance() } else { mistakes += 1 }
        return ok
    }

    /// A shake, tap, step or squat, depending on the mission.
    mutating func registerAction(count: Int = 1) {
        guard !isComplete, [.shake, .tap, .steps, .squat].contains(settings.kind), count > 0 else { return }
        completed = min(required, completed + count)
    }

    /// Absolute progress, e.g. the pedometer's step count since the mission started.
    mutating func setProgress(_ value: Int) {
        guard !isComplete, [.steps, .squat, .shake, .tap].contains(settings.kind) else { return }
        completed = min(required, max(completed, value))
    }

    /// Photo mission: the camera image matched the registered place.
    mutating func confirmPhotoMatch(distance: Double) -> Bool {
        guard settings.kind == .photo, !isComplete else { return isComplete }
        if PhotoMatch.isMatch(distance: distance) {
            completed = required
            return true
        }
        mistakes += 1
        return false
    }

    /// Memory mission: the user finished tapping cells for the current round.
    @discardableResult
    mutating func submitMemory(_ taps: Set<Int>) -> Bool {
        guard settings.kind == .memory, let puzzle = memory, !isComplete else { return false }
        if puzzle.isSolved(by: taps) {
            completed += 1
            advance()
            return true
        }
        mistakes += 1
        advance()
        return false
    }

    private mutating func advance() {
        guard !isComplete else { problem = nil; phrase = nil; memory = nil; return }
        switch settings.kind {
        case .math:
            problem = MathProblem.make(settings.difficulty, using: &rng)
        case .typing:
            var next = TypingPhrases.all[Int.random(in: 0..<TypingPhrases.all.count, using: &rng)]
            if next == phrase, TypingPhrases.all.count > 1 {
                next = TypingPhrases.all[(TypingPhrases.all.firstIndex(of: next)! + 1) % TypingPhrases.all.count]
            }
            phrase = next
        case .memory:
            memory = MemoryPuzzle.make(settings.difficulty, round: completed, using: &rng)
        default:
            break
        }
    }
}

/// Memory mission: some tiles light up, the user taps the same ones.
struct MemoryPuzzle: Equatable {
    let gridSize: Int
    let lit: Set<Int>

    var cellCount: Int { gridSize * gridSize }

    static func make<G: RandomNumberGenerator>(_ difficulty: MathDifficulty, round: Int, using rng: inout G) -> MemoryPuzzle {
        let size: Int
        let base: Int
        switch difficulty {
        case .easy: size = 3; base = 3
        case .medium: size = 4; base = 5
        case .hard: size = 5; base = 7
        }
        let count = min(size * size - 1, base + round)
        var cells = Array(0..<(size * size))
        cells.shuffle(using: &rng)
        return MemoryPuzzle(gridSize: size, lit: Set(cells.prefix(count)))
    }

    func isSolved(by taps: Set<Int>) -> Bool { taps == lit }
}

/// Barcode mission: compare a scanned payload with the registered one.
enum BarcodeMatcher {
    static func normalized(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    static func matches(scanned: String, registered: String?) -> Bool {
        guard let registered, !normalized(registered).isEmpty else { return false }
        return normalized(scanned) == normalized(registered)
    }
}

/// Photo mission: Vision feature-print distance below which two photos show the same place.
enum PhotoMatch {
    static let threshold: Double = 0.62
    static func isMatch(distance: Double) -> Bool { distance.isFinite && distance >= 0 && distance <= threshold }
}

/// Counts squats from vertical acceleration (in g, positive = up, gravity removed).
/// A squat is a downward dip followed by an upward push within a few seconds.
struct SquatDetector {
    var dipThreshold: Double = -0.25
    var pushThreshold: Double = 0.25
    var maxRepDuration: TimeInterval = 4
    var minInterval: TimeInterval = 0.8
    private var dipAt: TimeInterval?
    private var lastRep: TimeInterval = -.infinity

    init() {}

    mutating func ingest(vertical a: Double, at t: TimeInterval) -> Bool {
        if a <= dipThreshold {
            if dipAt == nil { dipAt = t }
            return false
        }
        if let dip = dipAt, a >= pushThreshold {
            dipAt = nil
            guard t - dip <= maxRepDuration, t - lastRep >= minInterval else { return false }
            lastRep = t
            return true
        }
        if let dip = dipAt, t - dip > maxRepDuration { dipAt = nil }
        return false
    }
}

/// Runs an alarm's missions one after another.
struct MissionChain {
    let missions: [MissionSettings]
    private(set) var index = 0
    private(set) var current: MissionSession?

    init(missions: [MissionSettings]) {
        self.missions = missions.filter { $0.kind != .none && $0.isReady }
        current = self.missions.first.map { MissionSession(settings: $0) }
    }

    var isComplete: Bool { index >= missions.count }
    var stepText: String { missions.count > 1 ? "Mission \(min(index + 1, missions.count)) of \(missions.count)" : "" }

    /// Call after mutating `current`; moves on when it is finished.
    mutating func update(_ session: MissionSession) {
        current = session
        guard session.isComplete else { return }
        index += 1
        current = index < missions.count ? MissionSession(settings: missions[index]) : nil
    }
}

/// Type-erased RNG so `MissionSession` can be seeded in tests.
struct SystemRandomNumberGeneratorBox: RandomNumberGenerator {
    private var nextImpl: () -> UInt64
    init<G: RandomNumberGenerator>(_ base: G) {
        var b = base
        nextImpl = { b.next() }
    }
    mutating func next() -> UInt64 { nextImpl() }
}

/// Small deterministic RNG for tests and previews.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E3779B97F4A7C15 : seed }
    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
