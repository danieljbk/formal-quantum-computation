import { describe, expect, it } from "vitest";
import {
  CHALLENGE_KINDS,
  checkMemoryInput,
  isShake,
  makeMathProblem,
  makeMemoryPattern,
  makeSequenceBoard,
  pickPhrase,
  seededRng,
  typingMatches,
} from "../src/lib/challenges";

describe("challenge catalog", () => {
  it("offers at least five interactive missions", () => {
    expect(CHALLENGE_KINDS.length).toBeGreaterThanOrEqual(5);
  });
});

describe("math", () => {
  it("produces answers consistent with the displayed expression", () => {
    const rng = seededRng(42);
    for (const d of ["easy", "medium", "hard"] as const) {
      for (let i = 0; i < 50; i++) {
        const p = makeMathProblem(d, rng);
        const expr = p.text.replace("×", "*").replace("−", "-");
        expect(Function(`return (${expr})`)()).toBe(p.answer);
      }
    }
  });
});

describe("typing", () => {
  it("is lenient on easy/medium, exact on hard", () => {
    expect(typingMatches("Rise and shine", "  rise   and SHINE ", "easy")).toBe(true);
    expect(typingMatches("I will not hit snooze again", "i will not hit snooze", "medium")).toBe(false);
    const hard = pickPhrase("hard", seededRng(1));
    expect(typingMatches(hard, hard, "hard")).toBe(true);
    expect(typingMatches(hard, hard.toLowerCase(), "hard")).toBe(false);
  });
});

describe("memory", () => {
  it("never repeats the same tile twice in a row and validates prefixes", () => {
    const p = makeMemoryPattern(8, seededRng(7));
    expect(p).toHaveLength(8);
    for (let i = 1; i < p.length; i++) expect(p[i]).not.toBe(p[i - 1]);
    expect(checkMemoryInput(p, p.slice(0, 3))).toBe("continue");
    expect(checkMemoryInput(p, p)).toBe("complete");
    expect(checkMemoryInput(p, [(p[0] + 1) % 9])).toBe("wrong");
  });
});

describe("sequence", () => {
  it("is a permutation of 1..n", () => {
    const b = makeSequenceBoard(12, seededRng(3));
    expect([...b].sort((x, y) => x - y)).toEqual(Array.from({ length: 12 }, (_, i) => i + 1));
  });
});

describe("shake detection", () => {
  it("counts strong, debounced motion only", () => {
    expect(isShake({ x: 20, y: 0, z: 0 }, 0, 1000)).toBe(true);
    expect(isShake({ x: 3, y: 2, z: 1 }, 0, 1000)).toBe(false);
    expect(isShake({ x: 20, y: 0, z: 0 }, 900, 1000)).toBe(false);
    expect(isShake(null, 0, 1000)).toBe(false);
  });
});
