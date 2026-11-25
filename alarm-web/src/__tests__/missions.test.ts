import { describe, expect, it } from 'vitest';
import {
  checkMathAnswer,
  checkMemory,
  checkPhrase,
  clampRounds,
  createRng,
  createShakeDetector,
  generateMathProblem,
  generateMemoryPuzzle,
  generatePhrase,
} from '../missions';

describe('math missions', () => {
  it('generates problems whose answers check out at every difficulty', () => {
    const rng = createRng(42);
    for (const d of ['easy', 'medium', 'hard'] as const) {
      for (let i = 0; i < 50; i++) {
        const p = generateMathProblem(d, rng);
        // Evaluate the prompt independently.
        const expr = p.prompt.replace('×', '*').replace('−', '-');
        expect(Function(`return (${expr})`)()).toBe(p.answer);
        expect(checkMathAnswer(p, String(p.answer))).toBe(true);
        expect(checkMathAnswer(p, ` ${p.answer} `)).toBe(true);
        expect(checkMathAnswer(p, String(p.answer + 1))).toBe(false);
        expect(checkMathAnswer(p, '')).toBe(false);
        expect(checkMathAnswer(p, `${p.answer}.0`)).toBe(false);
      }
    }
  });

  it('is deterministic for a seed', () => {
    expect(generateMathProblem('hard', createRng(7))).toEqual(generateMathProblem('hard', createRng(7)));
  });
});

describe('typing missions', () => {
  it('accepts the phrase regardless of case and spacing, rejects others', () => {
    const phrase = generatePhrase('medium', createRng(1));
    expect(checkPhrase(phrase, phrase.toUpperCase())).toBe(true);
    expect(checkPhrase(phrase, `  ${phrase.replace(/ /g, '   ')} `)).toBe(true);
    expect(checkPhrase(phrase, phrase.slice(0, -1))).toBe(false);
  });
});

describe('memory missions', () => {
  it('generates distinct in-range tiles of the right count', () => {
    const rng = createRng(3);
    const cases = { easy: [3, 3], medium: [3, 4], hard: [4, 6] } as const;
    for (const [d, [size, count]] of Object.entries(cases) as [keyof typeof cases, readonly [number, number]][]) {
      const p = generateMemoryPuzzle(d, rng);
      expect(p.gridSize).toBe(size);
      expect(new Set(p.tiles).size).toBe(count);
      expect(p.tiles.every((t) => t >= 0 && t < size * size)).toBe(true);
    }
  });

  it('checks the exact set of tiles', () => {
    const p = { gridSize: 3, tiles: [0, 4, 8] };
    expect(checkMemory(p, [8, 0, 4])).toBe(true);
    expect(checkMemory(p, [0, 4])).toBe(false);
    expect(checkMemory(p, [0, 4, 7])).toBe(false);
  });
});

describe('shake detection', () => {
  it('counts strong jolts once per refractory window', () => {
    const detect = createShakeDetector(12, 250);
    const jolt = { x: 25, y: 0, z: 0 };
    const still = { x: 0, y: 0, z: 9.81 };
    expect(detect(still, 0)).toBe(false);
    expect(detect(jolt, 10)).toBe(true);
    expect(detect(jolt, 100)).toBe(false);
    expect(detect(jolt, 300)).toBe(true);
  });
});

describe('rounds', () => {
  it('clamps per mission kind', () => {
    expect(clampRounds({ kind: 'none', difficulty: 'easy', rounds: 3 })).toBe(0);
    expect(clampRounds({ kind: 'shake', difficulty: 'easy', rounds: 3 })).toBe(1);
    expect(clampRounds({ kind: 'math', difficulty: 'easy', rounds: 9 })).toBe(5);
    expect(clampRounds({ kind: 'typing', difficulty: 'easy', rounds: 0 })).toBe(1);
  });
});
