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
        default:
            ok = false
        }
        if ok { completed += 1; advance() } else { mistakes += 1 }
        return ok
    }

    /// A shake or a tap, depending on the mission.
    mutating func registerAction() {
        guard !isComplete, settings.kind == .shake || settings.kind == .tap else { return }
        completed += 1
    }

    private mutating func advance() {
        guard !isComplete else { problem = nil; phrase = nil; return }
        switch settings.kind {
        case .math:
            problem = MathProblem.make(settings.difficulty, using: &rng)
        case .typing:
            var next = TypingPhrases.all[Int.random(in: 0..<TypingPhrases.all.count, using: &rng)]
            if next == phrase, TypingPhrases.all.count > 1 {
                next = TypingPhrases.all[(TypingPhrases.all.firstIndex(of: next)! + 1) % TypingPhrases.all.count]
            }
            phrase = next
        default:
            break
        }
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
