import { randInt, rng, shuffle } from './random';
import type { Difficulty, MissionConfig, MissionKind } from './types';

export interface MissionInfo {
  kind: MissionKind;
  title: string;
  icon: string;
  blurb: string;
  defaultRounds: number;
}

/** Every mission is a gate: the alarm cannot be dismissed until all of an alarm's gates are cleared. */
export const MISSIONS: readonly MissionInfo[] = [
  { kind: 'math', title: 'Bottle Math', icon: '🍼', blurb: 'Solve arithmetic problems.', defaultRounds: 3 },
  { kind: 'typing', title: 'Promise Typing', icon: '⌨️', blurb: 'Type a wake-up promise exactly.', defaultRounds: 1 },
  { kind: 'memory', title: 'Toy Memory', icon: '🧸', blurb: 'Remember which tiles lit up.', defaultRounds: 2 },
  { kind: 'rock', title: 'Rock the Cradle', icon: '🫨', blurb: 'Shake your phone (or tap fast) to rock the cradle.', defaultRounds: 1 },
  { kind: 'sequence', title: 'Block Order', icon: '🔢', blurb: 'Tap the numbered blocks in order.', defaultRounds: 2 },
  { kind: 'colors', title: 'Crayon Check', icon: '🖍️', blurb: 'Pick the ink colour, not the word.', defaultRounds: 5 },
];

export function missionInfo(kind: MissionKind): MissionInfo {
  const info = MISSIONS.find((m) => m.kind === kind);
  if (!info) throw new Error(`unknown mission ${kind}`);
  return info;
}

export function defaultMission(kind: MissionKind, difficulty: Difficulty = 'normal'): MissionConfig {
  return { kind, difficulty, rounds: missionInfo(kind).defaultRounds };
}

// ---------- Math ----------
export interface MathProblem {
  text: string;
  answer: number;
}

export function mathProblem(seed: number, difficulty: Difficulty): MathProblem {
  const r = rng(seed);
  if (difficulty === 'easy') {
    const a = randInt(r, 10, 49);
    const b = randInt(r, 10, 49);
    return { text: `${a} + ${b}`, answer: a + b };
  }
  if (difficulty === 'normal') {
    const a = randInt(r, 3, 12);
    const b = randInt(r, 6, 19);
    const c = randInt(r, 10, 99);
    return { text: `${a} × ${b} + ${c}`, answer: a * b + c };
  }
  const a = randInt(r, 11, 29);
  const b = randInt(r, 11, 29);
  const c = randInt(r, 3, 9);
  const d = randInt(r, 11, 49);
  return { text: `${a} × ${b} − ${c} × ${d}`, answer: a * b - c * d };
}

// ---------- Typing ----------
const PHRASES: Record<Difficulty, readonly string[]> = {
  easy: ['I am awake', 'Good morning baby', 'Up and at them', 'No more snoozing'],
  normal: [
    'I am awake and the baby needs me',
    'Bottles do not warm themselves',
    'Today I get up on the first cry',
    'Morning me is stronger than night me',
  ],
  hard: [
    'Whoever invented the snooze button never met a hungry newborn at six in the morning.',
    'I solemnly swear that I am out of bed, upright, and fully prepared for diaper duty.',
    'Rise, shine, warm the bottle, find the pacifier, and do not get back under the covers.',
  ],
};

export function typingPhrase(seed: number, difficulty: Difficulty): string {
  const list = PHRASES[difficulty];
  return list[Math.floor(rng(seed)() * list.length)];
}

export function normalizePhrase(s: string): string {
  return s.trim().replace(/\s+/g, ' ').toLowerCase();
}

export function typingMatches(target: string, typed: string): boolean {
  return normalizePhrase(target) === normalizePhrase(typed);
}

// ---------- Memory ----------
export interface MemoryBoard {
  size: number;
  lit: number[];
}

export function memoryBoard(seed: number, difficulty: Difficulty): MemoryBoard {
  const size = difficulty === 'easy' ? 3 : difficulty === 'normal' ? 4 : 5;
  const count = difficulty === 'easy' ? 3 : difficulty === 'normal' ? 5 : 7;
  const cells = Array.from({ length: size * size }, (_, i) => i);
  return { size, lit: shuffle(rng(seed), cells).slice(0, count).sort((a, b) => a - b) };
}

export function memoryMatches(board: MemoryBoard, picked: readonly number[]): boolean {
  const p = [...new Set(picked)].sort((a, b) => a - b);
  return p.length === board.lit.length && p.every((v, i) => v === board.lit[i]);
}

// ---------- Rock (shake) ----------
export function rockTarget(difficulty: Difficulty): number {
  return difficulty === 'easy' ? 25 : difficulty === 'normal' ? 45 : 80;
}

/** Shake detection: acceleration magnitude change above threshold counts as one rock. */
export const SHAKE_THRESHOLD = 14;

export function isShake(prev: { x: number; y: number; z: number }, cur: { x: number; y: number; z: number }): boolean {
  const delta = Math.abs(cur.x - prev.x) + Math.abs(cur.y - prev.y) + Math.abs(cur.z - prev.z);
  return delta > SHAKE_THRESHOLD;
}

// ---------- Sequence ----------
export function sequenceBoard(seed: number, difficulty: Difficulty): number[] {
  const n = difficulty === 'easy' ? 6 : difficulty === 'normal' ? 9 : 16;
  return shuffle(rng(seed), Array.from({ length: n }, (_, i) => i + 1));
}

/** Returns the next expected value after a tap, or 1 again if the tap was wrong (progress resets). */
export function sequenceStep(expected: number, tapped: number): number {
  return tapped === expected ? expected + 1 : 1;
}

// ---------- Colours (Stroop) ----------
export const CRAYONS = [
  { name: 'RED', hex: '#e5484d' },
  { name: 'BLUE', hex: '#3e63dd' },
  { name: 'GREEN', hex: '#30a46c' },
  { name: 'YELLOW', hex: '#f5d90a' },
  { name: 'PURPLE', hex: '#8e4ec6' },
  { name: 'ORANGE', hex: '#f76b15' },
] as const;

export interface ColorRound {
  word: string;
  ink: string;
  inkName: string;
  options: string[];
}

export function colorRound(seed: number, difficulty: Difficulty): ColorRound {
  const r = rng(seed);
  const n = difficulty === 'easy' ? 3 : difficulty === 'normal' ? 4 : 6;
  const pool = shuffle(r, CRAYONS).slice(0, n);
  const ink = pool[0];
  const word = pool[1];
  return { word: word.name, ink: ink.hex, inkName: ink.name, options: shuffle(r, pool.map((c) => c.name)) };
}

/** Derive a stable sub-seed for (mission index, round). */
export function subSeed(seed: number, missionIndex: number, round: number): number {
  return (seed ^ Math.imul(missionIndex + 1, 0x9e3779b1) ^ Math.imul(round + 1, 0x85ebca6b)) >>> 0;
}
