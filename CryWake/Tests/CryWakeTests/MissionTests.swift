import XCTest
@testable import CryWake

final class MissionTests: XCTestCase {
    func testMathProblemsAreCorrectForEveryDifficulty() {
        var rng = SeededGenerator(seed: 42)
        for difficulty in MissionDifficulty.allCases {
            for _ in 0..<200 {
                let p = MathProblem.generate(difficulty, using: &rng)
                // Re-evaluate the displayed expression independently.
                let expr = p.text.replacingOccurrences(of: "\u{00D7}", with: "*")
                let value = NSExpression(format: expr).expressionValue(with: nil, context: nil) as! NSNumber
                XCTAssertEqual(value.intValue, p.answer, "\(p.text)")
                XCTAssertTrue(p.check(" \(p.answer) "))
                XCTAssertFalse(p.check("\(p.answer + 1)"))
                XCTAssertFalse(p.check(""))
            }
        }
    }

    func testSeededGeneratorIsDeterministic() {
        var a = SeededGenerator(seed: 7), b = SeededGenerator(seed: 7)
        XCTAssertEqual(MathProblem.generate(.hard, using: &a), MathProblem.generate(.hard, using: &b))
    }

    func testHarderMissionsNeedMoreWork() {
        XCTAssertLessThan(MissionTargets.shakes(.easy), MissionTargets.shakes(.normal))
        XCTAssertLessThan(MissionTargets.shakes(.normal), MissionTargets.shakes(.hard))
        XCTAssertLessThan(MissionTargets.taps(.easy), MissionTargets.taps(.hard))
        for d in MissionDifficulty.allCases {
            XCTAssertFalse(MissionTargets.lullabyLines[d]!.isEmpty)
        }
    }

    func testTypingToleratesSmartApostropheAndWhitespace() {
        let target = "Hush little baby, don't say a word"
        XCTAssertTrue(MissionTargets.typingMatches("Hush little baby, don\u{2019}t say a word ", target: target))
        XCTAssertFalse(MissionTargets.typingMatches("hush little baby, don't say a word", target: target))
        XCTAssertFalse(MissionTargets.typingMatches("Hush little baby", target: target))
    }

    func testShakeCounterThresholdAndDebounce() {
        var c = ShakeCounter()
        XCTAssertFalse(c.feed(x: 0, y: 0, z: 1, at: 0))      // resting phone, 1 g
        XCTAssertTrue(c.feed(x: 2.5, y: 0, z: 1, at: 0.1))   // shake
        XCTAssertFalse(c.feed(x: 2.5, y: 0, z: 1, at: 0.2))  // same shake, debounced
        XCTAssertTrue(c.feed(x: -2.2, y: 1, z: 0, at: 0.5))  // next shake
        XCTAssertEqual(c.count, 2)
    }
}
