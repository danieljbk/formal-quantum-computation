import XCTest
@testable import BabyAlarm

final class MissionTests: XCTestCase {
    func testMathProblemsHaveCorrectAnswers() {
        var rng = SeededGenerator(seed: 42)
        for difficulty in MathDifficulty.allCases {
            for _ in 0..<50 {
                let p = MathProblem.make(difficulty, using: &rng)
                let expr = p.prompt.replacingOccurrences(of: "×", with: "*")
                XCTAssertEqual(evaluate(expr), p.answer, p.prompt)
            }
        }
    }

    func testMathMissionCompletesAfterAllRounds() {
        var session = MissionSession(settings: MissionSettings(kind: .math, difficulty: .medium, rounds: 3),
                                     rng: SeededGenerator(seed: 7))
        XCTAssertFalse(session.isComplete)
        XCTAssertFalse(session.submit("not a number"))
        XCTAssertEqual(session.mistakes, 1)
        for _ in 0..<3 {
            XCTAssertTrue(session.submit(String(session.problem!.answer)))
        }
        XCTAssertTrue(session.isComplete)
        XCTAssertEqual(session.progress, 1)
        XCTAssertNil(session.problem)
    }

    func testTypingMissionNormalizesInput() {
        XCTAssertTrue(TypingPhrases.matches("  i AM awake,  and the baby can stop crying!", "I am awake and the baby can stop crying"))
        XCTAssertFalse(TypingPhrases.matches("I am awake", "I am awake and the baby can stop crying"))
        var session = MissionSession(settings: MissionSettings(kind: .typing, difficulty: .easy, rounds: 2),
                                     rng: SeededGenerator(seed: 3))
        let first = session.phrase!
        XCTAssertTrue(session.submit(first.uppercased()))
        XCTAssertNotEqual(session.phrase, first)
        XCTAssertTrue(session.submit(session.phrase!))
        XCTAssertTrue(session.isComplete)
    }

    func testShakeAndTapMissionsCountActions() {
        var shake = MissionSession(settings: MissionSettings(kind: .shake, difficulty: .easy, rounds: 10))
        for _ in 0..<9 { shake.registerAction() }
        XCTAssertFalse(shake.isComplete)
        shake.registerAction()
        XCTAssertTrue(shake.isComplete)

        // Out-of-range rounds are clamped to the mission's range.
        var tap = MissionSession(settings: MissionSettings(kind: .tap, difficulty: .easy, rounds: 1))
        XCTAssertEqual(tap.required, MissionKind.tap.roundsRange.lowerBound)
        for _ in 0..<tap.required { tap.registerAction() }
        XCTAssertTrue(tap.isComplete)
    }

    func testNoMissionIsImmediatelyComplete() {
        XCTAssertTrue(MissionSession(settings: .off).isComplete)
    }

    func testShakeDetectorDebounces() {
        var d = ShakeDetector(threshold: 1.4, minInterval: 0.25)
        XCTAssertTrue(d.ingest(x: 2, y: 0, z: 0, at: 0.0))
        XCTAssertFalse(d.ingest(x: 2, y: 0, z: 0, at: 0.05), "must drop below threshold before re-arming")
        XCTAssertFalse(d.ingest(x: 0.1, y: 0, z: 0, at: 0.1))
        XCTAssertFalse(d.ingest(x: 2, y: 0, z: 0, at: 0.15), "too soon after the previous shake")
        XCTAssertFalse(d.ingest(x: 0.1, y: 0, z: 0, at: 0.3))
        XCTAssertTrue(d.ingest(x: 0, y: 1.5, z: 0.5, at: 0.4))
        XCTAssertFalse(d.ingest(x: 0.5, y: 0.5, z: 0.5, at: 1.0), "gentle movement is not a shake")
    }

    // Minimal evaluator for "a op b op c ..." with * binding tighter than +.
    private func evaluate(_ expr: String) -> Int {
        expr.components(separatedBy: "+").map { term in
            term.components(separatedBy: "*").map { Int($0.trimmingCharacters(in: .whitespaces))! }.reduce(1, *)
        }.reduce(0, +)
    }
}
