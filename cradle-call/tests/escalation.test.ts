import { describe, expect, it } from 'vitest';
import { escalationAt, layerVoices, MISSION_DUCK, STAGES } from '../src/core/escalation';

describe('multi-stage escalation ramp', () => {
  it('has several stages with increasing volume and layers', () => {
    expect(STAGES.length).toBeGreaterThanOrEqual(3);
    for (let i = 1; i < STAGES.length; i++) {
      expect(STAGES[i].startsAt).toBeGreaterThan(STAGES[i - 1].startsAt);
      expect(STAGES[i].fromVolume).toBeGreaterThanOrEqual(STAGES[i - 1].toVolume);
      expect(STAGES[i].layers).toBeGreaterThanOrEqual(STAGES[i - 1].layers);
    }
    expect(STAGES[STAGES.length - 1].layers).toBeGreaterThan(STAGES[0].layers);
  });

  it('volume never decreases over time', () => {
    let prev = -1;
    for (let t = 0; t <= 200; t += 0.5) {
      const v = escalationAt(t).volume;
      expect(v).toBeGreaterThanOrEqual(prev);
      prev = v;
    }
    expect(escalationAt(0).volume).toBeLessThan(0.2);
    expect(escalationAt(500).volume).toBeCloseTo(1);
  });

  it('is not a flat single clip', () => {
    const levels = new Set([0, 30, 60, 120].map((t) => escalationAt(t).stageIndex));
    expect(levels.size).toBe(4);
  });

  it('respects the max-volume ceiling and ducks during missions', () => {
    expect(escalationAt(500, 0.5).volume).toBeCloseTo(0.5);
    expect(escalationAt(500, 1, true).volume).toBeCloseTo(MISSION_DUCK);
    expect(escalationAt(500, 1, true).layers).toBe(1);
  });

  it('adds other babies after the chosen one', () => {
    expect(layerVoices('b', ['a', 'b', 'c', 'd'], 3)).toEqual(['b', 'a', 'c']);
    expect(layerVoices('b', ['a', 'b'], 1)).toEqual(['b']);
  });
});
