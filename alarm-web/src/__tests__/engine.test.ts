import { describe, expect, it } from 'vitest';
import { IDLE, WAKE_CHECK_RESPONSE_MS, canSnooze, confirmAwake, dismiss, markFired, snooze, tick, wakeStats } from '../engine';
import { createAlarm } from '../storage';

const T0 = new Date(2026, 10, 25, 7, 0).getTime();
const created = new Date(2026, 10, 1).getTime();
const MIN = 60_000;

function morning(overrides = {}) {
  return createAlarm({ hour: 7, minute: 0, createdAt: created, ...overrides });
}

describe('ring lifecycle', () => {
  it('starts ringing when an alarm is due and marks it fired', () => {
    const a = morning();
    const r = tick(IDLE, [a], T0 + 1000);
    expect(r.phase).toMatchObject({ kind: 'ringing', alarmId: a.id, scheduledAt: T0, snoozeCount: 0 });
    expect(r.fired).toEqual([a.id]);
    const after = markFired([a], r.fired, T0 + 1000);
    expect(tick(IDLE, after, T0 + 2000).phase).toBe(IDLE);
  });

  it('does nothing before the alarm time', () => {
    expect(tick(IDLE, [morning()], T0 - MIN).phase).toBe(IDLE);
  });

  it('snoozes up to the limit and re-rings after the snooze', () => {
    const a = morning({ snooze: { enabled: true, minutes: 5, maxCount: 2 } });
    let p = tick(IDLE, [a], T0).phase;
    p = snooze(p, a, T0 + MIN);
    expect(p).toMatchObject({ kind: 'snoozed', until: T0 + 6 * MIN, snoozeCount: 1 });
    expect(tick(p, [a], T0 + 5 * MIN).phase.kind).toBe('snoozed');
    p = tick(p, [a], T0 + 6 * MIN).phase;
    expect(p).toMatchObject({ kind: 'ringing', snoozeCount: 1 });
    expect(canSnooze(p, a)).toBe(true);
    p = tick(snooze(p, a, T0 + 7 * MIN), [a], T0 + 12 * MIN).phase;
    expect(p).toMatchObject({ kind: 'ringing', snoozeCount: 2 });
    expect(canSnooze(p, a)).toBe(false);
    expect(snooze(p, a, T0 + 13 * MIN)).toBe(p);
  });

  it('cannot snooze when snooze is disabled', () => {
    const a = morning({ snooze: { enabled: false, minutes: 5, maxCount: 3 } });
    const p = tick(IDLE, [a], T0).phase;
    expect(canSnooze(p, a)).toBe(false);
  });

  it('dismissing logs a wake record', () => {
    const a = morning({ label: 'Work' });
    const p = tick(IDLE, [a], T0).phase;
    const res = dismiss(p, a, T0 + 3 * MIN);
    expect(res.phase).toBe(IDLE);
    expect(res.record).toMatchObject({ alarmId: a.id, label: 'Work', scheduledAt: T0, dismissedAt: T0 + 3 * MIN, snoozeCount: 0, mission: 'math' });
  });

  it('wake-up check re-rings if unanswered, and is cleared by confirming', () => {
    const a = morning({ wakeUpCheck: { enabled: true, afterMinutes: 5 } });
    const ring = tick(IDLE, [a], T0).phase;
    const { phase: waiting } = dismiss(ring, a, T0 + MIN);
    expect(waiting).toMatchObject({ kind: 'awaitingCheck', checkAt: T0 + 6 * MIN });
    const checking = tick(waiting, [a], T0 + 6 * MIN).phase;
    expect(checking).toMatchObject({ kind: 'checking', deadline: T0 + 6 * MIN + WAKE_CHECK_RESPONSE_MS });
    expect(confirmAwake(checking)).toBe(IDLE);
    const reRing = tick(checking, [a], T0 + 6 * MIN + WAKE_CHECK_RESPONSE_MS).phase;
    expect(reRing).toMatchObject({ kind: 'ringing', recheck: true });
    // A re-ring can't be snoozed and isn't logged twice, and doesn't schedule another check.
    expect(canSnooze(reRing, a)).toBe(false);
    const final = dismiss(reRing, a, T0 + 8 * MIN);
    expect(final).toEqual({ phase: IDLE, record: null });
  });

  it('retires one-shot alarms after they fire but keeps repeating ones on', () => {
    const once = morning();
    const repeat = morning({ repeatDays: [3] });
    const [o, r] = markFired([once, repeat], [once.id, repeat.id], T0);
    expect(o.enabled).toBe(false);
    expect(r.enabled).toBe(true);
    expect(r.lastFiredAt).toBe(T0);
  });

  it('rings a quick (one-shot) alarm at its exact time', () => {
    const at = T0 + 20 * MIN + 30_000;
    const nap = createAlarm({ oneShotAt: at, createdAt: T0 });
    expect(tick(IDLE, [nap], at - 1000).phase).toBe(IDLE);
    expect(tick(IDLE, [nap], at).phase).toMatchObject({ kind: 'ringing', scheduledAt: at });
  });
});

describe('wakeStats', () => {
  it('summarises history', () => {
    const rec = (delayMin: number, snoozeCount: number) => ({
      alarmId: 'a', label: 'x', scheduledAt: T0, dismissedAt: T0 + delayMin * MIN, snoozeCount, mission: 'math' as const,
    });
    expect(wakeStats([])).toEqual({ count: 0, avgDelayMin: 0, snoozes: 0, streak: 0 });
    expect(wakeStats([rec(10, 2), rec(2, 0), rec(3, 0)])).toEqual({ count: 3, avgDelayMin: 5, snoozes: 2, streak: 2 });
  });
});
