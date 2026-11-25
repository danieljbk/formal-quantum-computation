import { describe, expect, it } from 'vitest';
import { defaultMission } from '../src/core/missions';
import { canSnooze, initialState, loadState, makeAlarm, reducer, saveState, STORAGE_KEY, type Action } from '../src/core/store';
import type { AppState } from '../src/core/types';

const T0 = new Date(2026, 10, 25, 7, 0, 1).getTime(); // Wed 07:00:01

function withAlarm(partial = {}): AppState {
  const alarm = makeAlarm(0, { id: 'a1', hour: 7, minute: 0, repeat: [3], ...partial });
  return reducer(initialState(), { type: 'SAVE_ALARM', alarm });
}

function run(state: AppState, ...actions: Action[]): AppState {
  return actions.reduce(reducer, state);
}

describe('alarm lifecycle', () => {
  it('rings at the scheduled time', () => {
    const s = run(withAlarm(), { type: 'TICK', now: T0 });
    expect(s.ringing?.alarmId).toBe('a1');
    expect(s.ringing?.phase).toBe('ringing');
  });

  it('has no bypass: only completing every mission dismisses', () => {
    let s = run(withAlarm({ missions: [defaultMission('math'), defaultMission('typing')] }), { type: 'TICK', now: T0 });
    // Silencing attempts that must be refused while ringing.
    s = run(s, { type: 'DELETE_ALARM', id: 'a1' }, { type: 'TOGGLE_ALARM', id: 'a1' });
    expect(s.alarms[0].enabled).toBe(true);
    expect(s.ringing).not.toBeNull();
    // Completing a mission before starting the missions does nothing.
    s = run(s, { type: 'MISSION_COMPLETE', now: T0 + 1000, index: 0 });
    expect(s.ringing).not.toBeNull();
    s = run(s, { type: 'START_MISSIONS', now: T0 + 2000 });
    // Skipping ahead to the last mission is refused.
    s = run(s, { type: 'MISSION_COMPLETE', now: T0 + 3000, index: 1 });
    expect(s.ringing?.missionIndex).toBe(0);
    s = run(s, { type: 'MISSION_COMPLETE', now: T0 + 4000, index: 0 });
    expect(s.ringing?.missionIndex).toBe(1);
    s = run(s, { type: 'MISSION_COMPLETE', now: T0 + 5000, index: 1 });
    expect(s.ringing).toBeNull();
    expect(s.screen).toBe('briefing');
    expect(s.history).toHaveLength(1);
  });

  it('an alarm can never be saved without a mission', () => {
    const s = withAlarm({ missions: [] });
    expect(s.alarms[0].missions.length).toBeGreaterThanOrEqual(1);
  });

  it('snooze is limited and re-rings', () => {
    let s = run(withAlarm({ snoozeLimit: 1, snoozeMinutes: 5 }), { type: 'TICK', now: T0 });
    expect(canSnooze(s)).toBe(true);
    s = run(s, { type: 'SNOOZE', now: T0 + 1000 });
    expect(s.ringing).toBeNull();
    s = run(s, { type: 'TICK', now: T0 + 60_000 });
    expect(s.ringing).toBeNull();
    s = run(s, { type: 'TICK', now: T0 + 1000 + 5 * 60_000 });
    expect(s.ringing?.reason).toBe('snooze');
    expect(canSnooze(s)).toBe(false);
    const after = run(s, { type: 'SNOOZE', now: T0 + 400_000 });
    expect(after.ringing).not.toBeNull();
  });

  it('snooze limit of 0 means no snooze', () => {
    const s = run(withAlarm({ snoozeLimit: 0 }), { type: 'TICK', now: T0 }, { type: 'SNOOZE', now: T0 + 1 });
    expect(s.ringing).not.toBeNull();
  });

  it('idle during a mission returns to the full cry', () => {
    let s = run(withAlarm(), { type: 'TICK', now: T0 }, { type: 'START_MISSIONS', now: T0 + 1000 });
    s = run(s, { type: 'TICK', now: T0 + 1000 + 10_000 });
    expect(s.ringing?.phase).toBe('mission');
    s = run(s, { type: 'TICK', now: T0 + 1000 + 26_000 });
    expect(s.ringing?.phase).toBe('ringing');
  });

  it('wake-up check re-rings when ignored and is cleared when confirmed', () => {
    const dismissAt = T0 + 10_000;
    let s = run(withAlarm({ wakeCheck: true, wakeCheckMinutes: 5 }), { type: 'TICK', now: T0 }, { type: 'START_MISSIONS', now: T0 }, { type: 'MISSION_COMPLETE', now: dismissAt, index: 0 });
    expect(s.wakeChecks).toHaveLength(1);
    const due = dismissAt + 5 * 60_000;
    s = run(s, { type: 'TICK', now: due });
    expect(s.wakeChecks[0].deadline).toBe(due + 60_000);

    const confirmed = run(s, { type: 'CONFIRM_AWAKE', now: due + 5_000 });
    expect(confirmed.wakeChecks).toHaveLength(0);

    const ignored = run(s, { type: 'TICK', now: due + 61_000 });
    expect(ignored.ringing?.reason).toBe('wakeCheck');
    expect(canSnooze(ignored)).toBe(false);
  });

  it('one-shot alarms disable themselves after ringing', () => {
    const s = run(withAlarm({ repeat: [] }), { type: 'TICK', now: T0 });
    expect(s.ringing).not.toBeNull();
    expect(s.alarms[0].enabled).toBe(false);
  });

  it('quick nap alarm is scheduled N minutes ahead', () => {
    const s = run(initialState(), { type: 'QUICK_ALARM', now: T0, minutes: 20 });
    expect(s.alarms[0].hour).toBe(7);
    expect(s.alarms[0].minute).toBe(20);
    expect(s.alarms[0].repeat).toEqual([]);
  });

  it('a ringing alarm survives a reload', () => {
    const s = run(withAlarm(), { type: 'TICK', now: T0 });
    const mem = new Map<string, string>();
    saveState({ setItem: (k, v) => mem.set(k, v) }, s);
    const restored = loadState({ getItem: (k) => mem.get(k) ?? null });
    expect(mem.has(STORAGE_KEY)).toBe(true);
    expect(restored.ringing?.alarmId).toBe('a1');
  });
});
