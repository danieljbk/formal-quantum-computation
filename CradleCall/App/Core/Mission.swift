import Foundation

/// Challenges that must be completed before a crying alarm can be silenced.
enum MissionKind: String, Codable, CaseIterable, Identifiable {
    case math, typing, memory, shake, tapTarget, steps, barcode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .math: return "Math"
        case .typing: return "Typing"
        case .memory: return "Memory"
        case .shake: return "Shake"
        case .tapTarget: return "Tap the target"
        case .steps: return "Walk"
        case .barcode: return "Scan a barcode"
        }
    }

    var symbol: String {
        switch self {
        case .math: return "plus.forwardslash.minus"
        case .typing: return "keyboard"
        case .memory: return "square.grid.3x3.fill"
        case .shake: return "iphone.radiowaves.left.and.right"
        case .tapTarget: return "scope"
        case .steps: return "figure.walk"
        case .barcode: return "barcode.viewfinder"
        }
    }

    var summary: String {
        switch self {
        case .math: return "Solve arithmetic problems"
        case .typing: return "Type a phrase exactly"
        case .memory: return "Repeat a pattern of tiles"
        case .shake: return "Shake your phone"
        case .tapTarget: return "Catch a moving target"
        case .steps: return "Get up and walk"
        case .barcode: return "Scan a barcode in another room"
        }
    }

    /// Label for `MissionConfig.rounds`.
    var roundsNoun: String {
        switch self {
        case .math: return "problems"
        case .typing: return "phrases"
        case .memory: return "rounds"
        case .shake: return "shakes"
        case .tapTarget: return "taps"
        case .steps: return "steps"
        case .barcode: return "scans"
        }
    }

    var defaultRounds: Int {
        switch self {
        case .math: return 3
        case .typing: return 2
        case .memory: return 3
        case .shake: return 30
        case .tapTarget: return 15
        case .steps: return 30
        case .barcode: return 1
        }
    }

    var roundsRange: ClosedRange<Int> {
        switch self {
        case .math, .typing, .memory: return 1...10
        case .shake: return 10...200
        case .tapTarget: return 5...60
        case .steps: return 10...300
        case .barcode: return 1...1
        }
    }

    var roundsStep: Int {
        switch self {
        case .shake, .steps: return 10
        case .tapTarget: return 5
        default: return 1
        }
    }
}

enum MissionDifficulty: Int, Codable, CaseIterable, Identifiable, Comparable {
    case easy, medium, hard, extreme

    var id: Int { rawValue }

    static func < (lhs: MissionDifficulty, rhs: MissionDifficulty) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .extreme: return "Extreme"
        }
    }
}

struct MissionConfig: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var kind: MissionKind
    var difficulty: MissionDifficulty = .medium
    var rounds: Int
    /// The registered code the barcode mission must match.
    var barcodeValue: String?

    init(kind: MissionKind, difficulty: MissionDifficulty = .medium, rounds: Int? = nil,
         barcodeValue: String? = nil) {
        self.kind = kind
        self.difficulty = difficulty
        self.rounds = rounds ?? kind.defaultRounds
        self.barcodeValue = barcodeValue
    }

    /// Whether the mission has everything it needs to run.
    var isReady: Bool {
        kind != .barcode || !(barcodeValue ?? "").isEmpty
    }

    var summary: String {
        if kind == .barcode { return isReady ? "Registered code" : "No code registered" }
        return "\(difficulty.title) · \(rounds) \(kind.roundsNoun)"
    }
}
