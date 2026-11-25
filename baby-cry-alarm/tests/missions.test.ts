import { describe, expect, it } from "vitest";
import {
  checkMath,
  checkPhrase,
  describeMission,
  makeMathProblem,
  makeRng,
  missionSteps,
  pickPhrase,
  RockDetector,
  TYPING_PHRASES,
} from "../src/missions";

describe("math missions", () => {
  it("produces correct answers at every difficulty", () => {
    const rng = makeRng(42);
    for (const d of [1, 2, 3] as const) {
      for (let i = 0; i < 200; i++) {
        const p = makeMathProblem(d, rng);
        const expr = p.prompt.replace("×", "*");
        // eslint-disable-next-line no-new-func
        expect(Function(`return ${expr}`)()).toBe(p.answer);
        expect(p.answer).toBeGreaterThan(0);
      }
    }
  });

  it("is deterministic for a seed", () => {
    expect(makeMathProblem(3, makeRng(7))).toEqual(makeMathProblem(3, makeRng(7)));
  });

  it("checks answers strictly", () => {
    const p = { prompt: "2 + 2", answer: 4 };
    expect(checkMath(p, " 4 ")).toBe(true);
    expect(checkMath(p, "5")).toBe(false);
    expect(checkMath(p, "4.0")).toBe(false);
    expect(checkMath(p, "")).toBe(false);
  });
});

describe("typing missions", () => {
  it("picks from the phrase list", () => {
    expect(TYPING_PHRASES).toContain(pickPhrase(makeRng(1)));
  });

  it("ignores case, spacing and punctuation but not words", () => {
    expect(checkPhrase("I will not go back to sleep", "i will NOT go  back to sleep!")).toBe(true);
    expect(checkPhrase("I will not go back to sleep", "I will go back to sleep")).toBe(false);
  });
});

describe("rock detector", () => {
  it("counts one rock per jolt, re-arming after the phone settles", () => {
    const r = new RockDetector(12);
    expect(r.feed(0, 15, 0)).toBe(true);
    expect(r.feed(0, 14, 0)).toBe(false); // same jolt
    expect(r.feed(0, 2, 0)).toBe(false); // settles, re-arms
    expect(r.feed(13, 0, 0)).toBe(true);
    expect(r.count).toBe(2);
  });
});

describe("mission summaries", () => {
  it("counts steps", () => {
    expect(missionSteps({ kind: "none" })).toBe(0);
    expect(missionSteps({ kind: "math", difficulty: 2, rounds: 3 })).toBe(3);
    expect(missionSteps({ kind: "rock", rocks: 20 })).toBe(20);
    expect(describeMission({ kind: "math", difficulty: 3, rounds: 2 })).toBe("Math · hard · 2×");
  });
});
