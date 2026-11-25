import Foundation

/// Deterministic generator so missions are reproducible in tests.
struct SplitMix64: RandomNumberGenerator {
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

// MARK: - Math

struct MathProblem: Equatable {
    let text: String
    let answer: Int
}

enum MathProblemGenerator {
    static func make<G: RandomNumberGenerator>(_ difficulty: MissionDifficulty, using rng: inout G) -> MathProblem {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 2...9, using: &rng)
            let b = Int.random(in: 10...49, using: &rng)
            return MathProblem(text: "\(b) + \(a)", answer: a + b)
        case .medium:
            let a = Int.random(in: 10...99, using: &rng)
            let b = Int.random(in: 10...99, using: &rng)
            let c = Int.random(in: 2...9, using: &rng)
            return MathProblem(text: "\(a) + \(b) + \(c)", answer: a + b + c)
        case .hard:
            let a = Int.random(in: 11...99, using: &rng)
            let b = Int.random(in: 3...9, using: &rng)
            let c = Int.random(in: 10...99, using: &rng)
            return MathProblem(text: "(\(a) × \(b)) + \(c)", answer: a * b + c)
        case .extreme:
            let a = Int.random(in: 101...999, using: &rng)
            let b = Int.random(in: 3...9, using: &rng)
            let c = Int.random(in: 11...99, using: &rng)
            let d = Int.random(in: 3...9, using: &rng)
            return MathProblem(text: "(\(a) × \(b)) − (\(c) × \(d))", answer: a * b - c * d)
        }
    }
}

// MARK: - Typing

enum TypingPhrases {
    static let all: [String] = [
        "I am awake and ready for today",
        "The baby is up so I am up too",
        "Feet on the floor and eyes wide open",
        "Every morning is a fresh start",
        "I will not crawl back into bed",
        "Coffee first then conquer the day",
        "Small steps lead to big mornings",
        "I chose this time for a reason",
        "Good mornings are made not found",
        "Rise and shine the crying stops now",
    ]

    static func pick<G: RandomNumberGenerator>(_ difficulty: MissionDifficulty, using rng: inout G) -> String {
        let base = all.randomElement(using: &rng) ?? all[0]
        switch difficulty {
        case .easy:
            return base.split(separator: " ").prefix(4).joined(separator: " ")
        case .medium:
            return base
        case .hard:
            return base + "."
        case .extreme:
            let second = all.randomElement(using: &rng) ?? all[1]
            return base + ". " + second + "."
        }
    }

    /// Whether `typed` matches `target`. Easy and medium ignore case and surrounding spaces.
    static func matches(_ typed: String, target: String, difficulty: MissionDifficulty) -> Bool {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        if difficulty >= .hard { return trimmed == target }
        return trimmed.caseInsensitiveCompare(target) == .orderedSame
    }
}

// MARK: - Memory

struct MemoryBoard: Equatable {
    enum TapResult: Equatable { case hit, alreadyFound, miss, complete }

    let side: Int
    let pattern: Set<Int>
    private(set) var found: Set<Int> = []

    var cellCount: Int { side * side }
    var isComplete: Bool { found == pattern }

    static func make<G: RandomNumberGenerator>(_ difficulty: MissionDifficulty, using rng: inout G) -> MemoryBoard {
        let (side, lit): (Int, Int)
        switch difficulty {
        case .easy: (side, lit) = (3, 3)
        case .medium: (side, lit) = (4, 5)
        case .hard: (side, lit) = (5, 7)
        case .extreme: (side, lit) = (5, 10)
        }
        var cells = Array(0..<(side * side))
        cells.shuffle(using: &rng)
        return MemoryBoard(side: side, pattern: Set(cells.prefix(lit)))
    }

    mutating func tap(_ index: Int) -> TapResult {
        guard pattern.contains(index) else { return .miss }
        guard !found.contains(index) else { return .alreadyFound }
        found.insert(index)
        return isComplete ? .complete : .hit
    }
}

// MARK: - Shake

/// Counts shakes from accelerometer magnitudes (in g) using hysteresis.
struct ShakeCounter {
    let highThreshold: Double
    let lowThreshold: Double
    let minimumInterval: TimeInterval
    private(set) var count = 0
    private var armed = true
    private var lastShake: TimeInterval = -.infinity

    init(difficulty: MissionDifficulty) {
        switch difficulty {
        case .easy: highThreshold = 1.6
        case .medium: highThreshold = 2.0
        case .hard: highThreshold = 2.4
        case .extreme: highThreshold = 2.8
        }
        lowThreshold = 1.2
        minimumInterval = 0.12
    }

    /// Feeds one sample; returns `true` when it completes a shake.
    @discardableResult
    mutating func add(magnitude: Double, at time: TimeInterval) -> Bool {
        if armed, magnitude >= highThreshold, time - lastShake >= minimumInterval {
            count += 1
            armed = false
            lastShake = time
            return true
        }
        if magnitude <= lowThreshold { armed = true }
        return false
    }

    mutating func reset() {
        count = 0
        armed = true
        lastShake = -.infinity
    }
}

/// Fallback step detection from accelerometer magnitude when no pedometer is available.
struct StepDetector {
    /// A walking step peaks around 1.15–1.3 g, far gentler than a deliberate shake.
    let highThreshold = 1.15
    let lowThreshold = 1.03
    let minimumInterval: TimeInterval = 0.3
    private(set) var steps = 0
    private var armed = true
    private var lastStep: TimeInterval = -.infinity

    @discardableResult
    mutating func add(magnitude: Double, at time: TimeInterval) -> Bool {
        if armed, magnitude >= highThreshold, time - lastStep >= minimumInterval {
            steps += 1
            armed = false
            lastStep = time
            return true
        }
        if magnitude <= lowThreshold { armed = true }
        return false
    }
}
