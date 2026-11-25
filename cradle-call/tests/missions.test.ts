import { describe, expect, it } from 'vitest';
import {
  colorRound,
  isShake,
  mathProblem,
  memoryBoard,
  memoryMatches,
  MISSIONS,
  sequenceBoard,
  sequenceStep,
  typingMatches,
  typingPhrase,
} from '../src/core/missions';
import type { Difficulty } from '../src/core/types';

const LEVELS: Difficulty[] = ['easy', 'normal', 'hard'];

describe('mission gates', () => {
  it('offers at least five distinct gates', () => {
    expect(new Set(MISSIONS.map((m) => m.kind)).size).toBeGreaterThanOrEqual(5);
  });

  it('math answers are consistent with the displayed problem', () => {
    for (const d of LEVELS)
      for (let seed = 1; seed < 50; seed++) {
        const p = mathProblem(seed, d);
        // eslint-disable-next-line no-new-func
        const evaluated = Function(`return ${p.text.replace(/×/g, '*').replace(/−/g, '-')}`)();
        expect(evaluated).toBe(p.answer);
      }
  });

  it('math is deterministic per seed', () => {
    expect(mathProblem(42, 'hard')).toEqual(mathProblem(42, 'hard'));
  });

  it('typing requires the exact phrase (case/spacing tolerant)', () => {
    const phrase = typingPhrase(7, 'normal');
    expect(typingMatches(phrase, `  ${phrase.toUpperCase()}  `)).toBe(true);
    expect(typingMatches(phrase, phrase.slice(0, -1))).toBe(false);
    expect(typingMatches(phrase, '')).toBe(false);
  });

  it('memory needs exactly the lit tiles', () => {
    const b = memoryBoard(3, 'normal');
    expect(b.lit.length).toBe(5);
    expect(memoryMatches(b, [...b.lit].reverse())).toBe(true);
    const wrong = [...b.lit.slice(1), b.lit.includes(0) ? 15 : 0];
    expect(memoryMatches(b, wrong)).toBe(false);
  });

  it('sequence resets on a wrong tap', () => {
    expect(sequenceBoard(1, 'easy').sort((a, b) => a - b)).toEqual([1, 2, 3, 4, 5, 6]);
    expect(sequenceStep(3, 3)).toBe(4);
    expect(sequenceStep(3, 5)).toBe(1);
  });

  it('colour rounds ask for an ink that differs from the word', () => {
    for (let seed = 0; seed < 50; seed++) {
      const r = colorRound(seed, 'hard');
      expect(r.word).not.toBe(r.inkName);
      expect(r.options).toContain(r.inkName);
    }
  });

  it('detects shakes', () => {
    expect(isShake({ x: 0, y: 0, z: 9.8 }, { x: 12, y: 6, z: 2 })).toBe(true);
    expect(isShake({ x: 0, y: 0, z: 9.8 }, { x: 0.3, y: 0.2, z: 9.6 })).toBe(false);
  });
});
