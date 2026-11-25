import type { Mission } from "./types";

/** Small deterministic PRNG (mulberry32) so missions are testable. */
export function makeRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function int(rng: () => number, lo: number, hi: number): number {
  return lo + Math.floor(rng() * (hi - lo + 1));
}

export interface MathProblem {
  prompt: string;
  answer: number;
}

/**
 * Difficulty 1: two-digit addition. 2: add three numbers. 3: a product plus a sum.
 * All answers are positive integers.
 */
export function makeMathProblem(difficulty: 1 | 2 | 3, rng: () => number): MathProblem {
  if (difficulty === 1) {
    const a = int(rng, 10, 49);
    const b = int(rng, 10, 49);
    return { prompt: `${a} + ${b}`, answer: a + b };
  }
  if (difficulty === 2) {
    const a = int(rng, 12, 89);
    const b = int(rng, 12, 89);
    const c = int(rng, 12, 89);
    return { prompt: `${a} + ${b} + ${c}`, answer: a + b + c };
  }
  const a = int(rng, 6, 19);
  const b = int(rng, 3, 9);
  const c = int(rng, 10, 99);
  return { prompt: `${a} × ${b} + ${c}`, answer: a * b + c };
}

export function checkMath(problem: MathProblem, input: string): boolean {
  const trimmed = input.trim();
  if (!/^-?\d+$/.test(trimmed)) return false;
  return Number(trimmed) === problem.answer;
}

export const TYPING_PHRASES = [
  "I am awake and the baby needs me",
  "Good morning sunshine time to get up",
  "Coffee first then everything else",
  "Nobody naps through this crying",
  "Feet on the floor and eyes wide open",
  "Today is going to be a good day",
  "Rise and shine the little one is calling",
  "I will not go back to sleep",
] as const;

export function pickPhrase(rng: () => number): string {
  return TYPING_PHRASES[Math.floor(rng() * TYPING_PHRASES.length)];
}

/** Case- and whitespace-insensitive, punctuation-tolerant comparison. */
export function normalizePhrase(s: string): string {
  return s
    .toLowerCase()
    .replace(/[^a-z0-9 ]+/g, "")
    .replace(/\s+/g, " ")
    .trim();
}

export function checkPhrase(target: string, input: string): boolean {
  return normalizePhrase(target) === normalizePhrase(input);
}

/** Total steps the user must complete to dismiss. */
export function missionSteps(m: Mission): number {
  switch (m.kind) {
    case "none":
      return 0;
    case "math":
    case "typing":
      return Math.max(1, m.rounds);
    case "rock":
      return Math.max(1, m.rocks);
  }
}

export function describeMission(m: Mission): string {
  switch (m.kind) {
    case "none":
      return "No mission";
    case "math":
      return `Math · ${["easy", "medium", "hard"][m.difficulty - 1]} · ${m.rounds}×`;
    case "typing":
      return `Type a phrase · ${m.rounds}×`;
    case "rock":
      return `Rock the baby · ${m.rocks} rocks`;
  }
}

/**
 * Shake detection for the "rock the baby" mission: a rock is counted when the
 * acceleration magnitude (gravity removed) crosses `threshold` after having
 * dropped below half of it, so one long jolt is one rock, not many.
 */
export class RockDetector {
  private armed = true;
  count = 0;

  constructor(private readonly threshold = 12) {}

  feed(x: number, y: number, z: number): boolean {
    const mag = Math.sqrt(x * x + y * y + z * z);
    if (this.armed && mag >= this.threshold) {
      this.armed = false;
      this.count++;
      return true;
    }
    if (!this.armed && mag < this.threshold / 2) this.armed = true;
    return false;
  }
}
