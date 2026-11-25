import { describe, expect, it } from 'vitest';
import { STORAGE_KEY, createAlarm, initialState, loadState, sanitizeAlarm, saveState, type KeyValueStore } from '../storage';

function memoryStore(initial: Record<string, string> = {}): KeyValueStore & { data: Record<string, string> } {
  const data = { ...initial };
  return { data, getItem: (k) => data[k] ?? null, setItem: (k, v) => void (data[k] = v) };
}

describe('storage', () => {
  it('starts with a disabled weekday morning alarm', () => {
    const s = loadState(memoryStore());
    expect(s.alarms).toHaveLength(1);
    expect(s.alarms[0]).toMatchObject({ hour: 7, minute: 0, enabled: false, repeatDays: [1, 2, 3, 4, 5] });
  });

  it('round-trips state', () => {
    const store = memoryStore();
    const state = initialState();
    state.alarms.push(createAlarm({ label: 'Gym', hour: 5, minute: 45, sound: 'kunjappi', repeatDays: [1, 3, 5] }));
    state.settings.use24h = true;
    saveState(store, state);
    expect(loadState(store)).toEqual(state);
  });

  it('survives corrupt or foreign data', () => {
    expect(loadState(memoryStore({ [STORAGE_KEY]: '{nope' })).alarms).toHaveLength(1);
    expect(loadState(memoryStore({ [STORAGE_KEY]: JSON.stringify({ version: 99 }) })).alarms).toHaveLength(1);
    const throwing: KeyValueStore = { getItem: () => { throw new Error('denied'); }, setItem: () => { throw new Error('denied'); } };
    expect(loadState(throwing).alarms).toHaveLength(1);
    expect(() => saveState(throwing, initialState())).not.toThrow();
  });

  it('repairs out-of-range alarm fields', () => {
    const a = sanitizeAlarm({ id: 'x', hour: 99, minute: -3, sound: 'trumpet', volume: 7, repeatDays: [1, 1, 9, 'a'], mission: { kind: 'karate', rounds: 50 } });
    expect(a).toMatchObject({ hour: 23, minute: 0, sound: 'newborn', volume: 1, repeatDays: [1], mission: { kind: 'math', rounds: 5 } });
    expect(sanitizeAlarm({ hour: 7 })).toBeNull();
    expect(sanitizeAlarm(null)).toBeNull();
  });
});
