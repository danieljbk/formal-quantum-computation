import Foundation

/// What the user has to do before the crying stops.
enum MissionKind: String, Codable, CaseIterable, Identifiable {
    case none
    case math
    case shake
    case typing
    case tap

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .math: return "Math"
        case .shake: return "Rock the baby"
        case .typing: return "Lullaby typing"
        case .tap: return "Pat the baby"
        }
    }

    var systemImage: String {
        switch self {
        case .none: return "xmark.circle"
        case .math: return "plus.forwardslash.minus"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .typing: return "keyboard"
        case .tap: return "hand.tap"
        }
    }

    var explanation: String {
        switch self {
        case .none: return "Tap once to soothe the baby."
        case .math: return "Solve arithmetic problems to calm the baby."
        case .shake: return "Shake your phone to rock the baby back to sleep."
        case .typing: return "Type a lullaby line exactly to calm the baby."
        case .tap: return "Pat the baby by tapping the screen many times."
        }
    }
}

enum MissionDifficulty: String, Codable, CaseIterable, Identifiable {
    case easy, normal, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

/// A generated arithmetic problem.
struct MathProblem: Equatable {
    let text: String
    let answer: Int

    static func generate<R: RandomNumberGenerator>(_ difficulty: MissionDifficulty, using rng: inout R) -> MathProblem {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 2...9, using: &rng)
            let b = Int.random(in: 10...49, using: &rng)
            return MathProblem(text: "\(b) + \(a)", answer: a + b)
        case .normal:
            let a = Int.random(in: 10...99, using: &rng)
            let b = Int.random(in: 10...99, using: &rng)
            let c = Int.random(in: 2...9, using: &rng)
            return MathProblem(text: "\(a) + \(b) + \(c)", answer: a + b + c)
        case .hard:
            let a = Int.random(in: 11...29, using: &rng)
            let b = Int.random(in: 3...9, using: &rng)
            let c = Int.random(in: 100...499, using: &rng)
            return MathProblem(text: "(\(a) \u{00D7} \(b)) + \(c)", answer: a * b + c)
        }
    }

    func check(_ input: String) -> Bool {
        Int(input.trimmingCharacters(in: .whitespacesAndNewlines)) == answer
    }
}

enum MissionTargets {
    static func shakes(_ d: MissionDifficulty) -> Int {
        switch d { case .easy: return 15; case .normal: return 30; case .hard: return 60 }
    }

    static func taps(_ d: MissionDifficulty) -> Int {
        switch d { case .easy: return 20; case .normal: return 40; case .hard: return 80 }
    }

    static let lullabyLines: [MissionDifficulty: [String]] = [
        .easy: [
            "hush little baby",
            "sleep baby sleep",
            "good morning sunshine",
        ],
        .normal: [
            "Hush little baby, don't say a word",
            "Twinkle twinkle little star",
            "Rock a bye baby on the tree top",
        ],
        .hard: [
            "Hush, little baby, don't say a word, Mama's gonna buy you a mockingbird.",
            "Twinkle, twinkle, little star, how I wonder what you are!",
            "Rock-a-bye baby, on the treetop; when the wind blows, the cradle will rock.",
        ],
    ]

    static func lullabyLine<R: RandomNumberGenerator>(_ d: MissionDifficulty, using rng: inout R) -> String {
        lullabyLines[d]!.randomElement(using: &rng)!
    }

    /// Typing check: exact match, but tolerant of surrounding whitespace and curly apostrophes
    /// inserted by the iOS keyboard's smart punctuation.
    static func typingMatches(_ input: String, target: String) -> Bool {
        func normalise(_ s: String) -> String {
            s.replacingOccurrences(of: "\u{2019}", with: "'")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return normalise(input) == normalise(target)
    }
}

/// Deterministic RNG (SplitMix64) so missions are testable.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
