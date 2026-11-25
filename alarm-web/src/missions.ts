import type { Difficulty, MissionConfig, MissionKind } from './types';

/** Small deterministic PRNG (mulberry32) so missions are testable. */
export function createRng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function randInt(rng: () => number, min: number, max: number): number {
  return min + Math.floor(rng() * (max - min + 1));
}

export const MISSION_INFO: Record<MissionKind, { title: string; blurb: string; emoji: string }> = {
  none: { title: 'Off', blurb: 'Just tap to stop the crying.', emoji: '🔕' },
  math: { title: 'Math', blurb: 'Solve problems to prove your brain is on.', emoji: '➗' },
  shake: { title: 'Shake', blurb: 'Rock the phone like a fussy baby.', emoji: '📳' },
  typing: { title: 'Typing', blurb: 'Type a phrase exactly.', emoji: '⌨️' },
  memory: { title: 'Memory', blurb: 'Repeat the pattern of lit tiles.', emoji: '🧩' },
  tap: { title: 'Tap', blurb: 'Tap the bouncing bottle again and again.', emoji: '🍼' },
};

// ---- Math -----------------------------------------------------------------

export interface MathProblem {
  prompt: string;
  answer: number;
}

export function generateMathProblem(difficulty: Difficulty, rng: () => number): MathProblem {
  switch (difficulty) {
    case 'easy': {
      const a = randInt(rng, 2, 19);
      const b = randInt(rng, 2, 19);
      return { prompt: `${a} + ${b}`, answer: a + b };
    }
    case 'medium': {
      const a = randInt(rng, 12, 59);
      const b = randInt(rng, 12, 59);
      const c = randInt(rng, 2, 9);
      return { prompt: `${a} + ${b} − ${c}`, answer: a + b - c };
    }
    case 'hard': {
      const a = randInt(rng, 12, 39);
      const b = randInt(rng, 3, 9);
      const c = randInt(rng, 11, 99);
      return { prompt: `${a} × ${b} + ${c}`, answer: a * b + c };
    }
  }
}

export function checkMathAnswer(problem: MathProblem, input: string): boolean {
  const trimmed = input.trim();
  if (!/^-?\d+$/.test(trimmed)) return false;
  return Number(trimmed) === problem.answer;
}

// ---- Typing ---------------------------------------------------------------

const PHRASES: Record<Difficulty, readonly string[]> = {
  easy: ['I am awake', 'Good morning', 'Rise and shine', 'Baby is fed', 'Up and at it'],
  medium: [
    'The baby is calm and so am I',
    'I will not go back to sleep',
    'Coffee first then the world',
    'Today I get out of bed on time',
  ],
  hard: [
    'Every morning I choose to stand up before the crying gets louder',
    'Sleep is lovely but my future self thanks me for waking up now',
    'A quiet nursery is earned one alarm at a time, starting right now',
  ],
};

export function generatePhrase(difficulty: Difficulty, rng: () => number): string {
  const list = PHRASES[difficulty];
  return list[randInt(rng, 0, list.length - 1)];
}

/** Exact match, but forgiving of case and surrounding/duplicate whitespace. */
export function checkPhrase(target: string, input: string): boolean {
  const norm = (s: string) => s.trim().replace(/\s+/g, ' ').toLowerCase();
  return norm(target) === norm(input);
}

// ---- Memory ---------------------------------------------------------------

export interface MemoryPuzzle {
  gridSize: number;
  /** Indices (0 … gridSize² − 1) of the tiles to remember. */
  tiles: number[];
}

export function generateMemoryPuzzle(difficulty: Difficulty, rng: () => number): MemoryPuzzle {
  const gridSize = difficulty === 'hard' ? 4 : 3;
  const count = difficulty === 'easy' ? 3 : difficulty === 'medium' ? 4 : 6;
  const cells = Array.from({ length: gridSize * gridSize }, (_, i) => i);
  for (let i = cells.length - 1; i > 0; i--) {
    const j = randInt(rng, 0, i);
    [cells[i], cells[j]] = [cells[j], cells[i]];
  }
  return { gridSize, tiles: cells.slice(0, count).sort((x, y) => x - y) };
}

export function checkMemory(puzzle: MemoryPuzzle, selected: Iterable<number>): boolean {
  const chosen = new Set(selected);
  return chosen.size === puzzle.tiles.length && puzzle.tiles.every((t) => chosen.has(t));
}

// ---- Shake & tap ----------------------------------------------------------

export function shakeTarget(difficulty: Difficulty): number {
  return difficulty === 'easy' ? 15 : difficulty === 'medium' ? 30 : 50;
}

export function tapTarget(difficulty: Difficulty): number {
  return difficulty === 'easy' ? 20 : difficulty === 'medium' ? 40 : 70;
}

/**
 * Shake detector: counts a shake when acceleration magnitude (minus gravity) crosses
 * `threshold`, with a refractory period so one jolt isn't counted many times.
 */
export function createShakeDetector(threshold = 12, refractoryMs = 250) {
  let lastShake = -Infinity;
  return (accel: { x: number; y: number; z: number }, timestamp: number): boolean => {
    const magnitude = Math.sqrt(accel.x ** 2 + accel.y ** 2 + accel.z ** 2);
    const net = Math.abs(magnitude - 9.81);
    if (net >= threshold && timestamp - lastShake >= refractoryMs) {
      lastShake = timestamp;
      return true;
    }
    return false;
  };
}

// ---- Shared ---------------------------------------------------------------

export function clampRounds(config: MissionConfig): number {
  if (config.kind === 'none') return 0;
  if (config.kind === 'shake' || config.kind === 'tap') return 1;
  return Math.min(5, Math.max(1, Math.round(config.rounds)));
}

export const DEFAULT_MISSION: MissionConfig = { kind: 'math', difficulty: 'easy', rounds: 3 };
