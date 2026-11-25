import type { ChallengeKind, Difficulty } from "./types";

export const CHALLENGES: Record<ChallengeKind, { name: string; emoji: string; description: string }> = {
  math: { name: "Math", emoji: "🧮", description: "Solve arithmetic problems" },
  shake: { name: "Shake", emoji: "📳", description: "Shake the phone (or tap fast)" },
  typing: { name: "Typing", emoji: "⌨️", description: "Type a wake-up phrase exactly" },
  memory: { name: "Memory", emoji: "🧠", description: "Repeat a flashing tile pattern" },
  rock: { name: "Rock the Baby", emoji: "🍼", description: "Hold steady to soothe the baby" },
  sequence: { name: "Sequence", emoji: "🔢", description: "Tap numbers in ascending order" },
};

export const CHALLENGE_KINDS = Object.keys(CHALLENGES) as ChallengeKind[];

export function randInt(rng: () => number, lo: number, hi: number): number {
  return lo + Math.floor(rng() * (hi - lo + 1));
}

// ---------- Math ----------
export interface MathProblem {
  text: string;
  answer: number;
}

export function makeMathProblem(difficulty: Difficulty, rng: () => number = Math.random): MathProblem {
  if (difficulty === "easy") {
    const a = randInt(rng, 2, 20);
    const b = randInt(rng, 2, 20);
    return { text: `${a} + ${b}`, answer: a + b };
  }
  if (difficulty === "medium") {
    const a = randInt(rng, 11, 49);
    const b = randInt(rng, 11, 49);
    const c = randInt(rng, 2, 9);
    return { text: `${a} + ${b} × ${c}`, answer: a + b * c };
  }
  const a = randInt(rng, 12, 39);
  const b = randInt(rng, 12, 39);
  const c = randInt(rng, 101, 499);
  return { text: `${a} × ${b} − ${c}`, answer: a * b - c };
}

export function mathRounds(difficulty: Difficulty): number {
  return difficulty === "easy" ? 2 : difficulty === "medium" ? 3 : 4;
}

// ---------- Shake ----------
export function shakeTarget(difficulty: Difficulty): number {
  return difficulty === "easy" ? 15 : difficulty === "medium" ? 30 : 50;
}

/** Magnitude (m/s², gravity removed) above which a motion sample counts as one shake. */
export const SHAKE_THRESHOLD = 14;
/** Minimum time between two counted shakes. */
export const SHAKE_DEBOUNCE_MS = 250;

export function isShake(
  accel: { x: number | null; y: number | null; z: number | null } | null,
  lastShakeAt: number,
  now: number,
): boolean {
  if (!accel) return false;
  const m = Math.hypot(accel.x ?? 0, accel.y ?? 0, accel.z ?? 0);
  return m >= SHAKE_THRESHOLD && now - lastShakeAt >= SHAKE_DEBOUNCE_MS;
}

// ---------- Typing ----------
const PHRASES: Record<Difficulty, string[]> = {
  easy: ["I am awake", "Good morning", "Rise and shine", "Up I get"],
  medium: [
    "The baby is louder than my excuses",
    "I will not hit snooze again",
    "Coffee is waiting for me downstairs",
    "Today I wake up on the first cry",
  ],
  hard: [
    "Somnolent procrastination yields to diurnal responsibility.",
    "Quietly, the swaddled infant demanded 6:45 AM breakfast!",
    "Exhausted parents synchronize circadian rhythms (eventually).",
    "Bleary-eyed, I acknowledge: sleep-deprivation builds character.",
  ],
};

export function pickPhrase(difficulty: Difficulty, rng: () => number = Math.random): string {
  const list = PHRASES[difficulty];
  return list[randInt(rng, 0, list.length - 1)];
}

/** Whitespace is normalised; case and punctuation must match on hard only. */
export function typingMatches(target: string, input: string, difficulty: Difficulty): boolean {
  const norm = (s: string) => s.trim().replace(/\s+/g, " ");
  if (difficulty === "hard") return norm(target) === norm(input);
  const loose = (s: string) => norm(s).toLowerCase().replace(/[^a-z0-9 ]/g, "");
  return loose(target) === loose(input);
}

// ---------- Memory ----------
export const MEMORY_GRID = 9;

export function memoryLength(difficulty: Difficulty): number {
  return difficulty === "easy" ? 4 : difficulty === "medium" ? 6 : 8;
}

export function makeMemoryPattern(length: number, rng: () => number = Math.random): number[] {
  const out: number[] = [];
  while (out.length < length) {
    const n = randInt(rng, 0, MEMORY_GRID - 1);
    if (out[out.length - 1] !== n) out.push(n);
  }
  return out;
}

export type MemoryProgress = "continue" | "complete" | "wrong";

export function checkMemoryInput(pattern: number[], input: number[]): MemoryProgress {
  for (let i = 0; i < input.length; i++) if (input[i] !== pattern[i]) return "wrong";
  return input.length === pattern.length ? "complete" : "continue";
}

// ---------- Rock the baby ----------
export function rockSeconds(difficulty: Difficulty): number {
  return difficulty === "easy" ? 3 : difficulty === "medium" ? 5 : 8;
}

// ---------- Sequence ----------
export function sequenceSize(difficulty: Difficulty): number {
  return difficulty === "easy" ? 6 : difficulty === "medium" ? 9 : 12;
}

/** Shuffled 1..n (Fisher–Yates). */
export function makeSequenceBoard(n: number, rng: () => number = Math.random): number[] {
  const arr = Array.from({ length: n }, (_, i) => i + 1);
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

/** Seeded PRNG (mulberry32) for reproducible tests. */
export function seededRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
