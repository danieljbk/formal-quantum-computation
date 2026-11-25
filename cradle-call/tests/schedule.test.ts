import { describe, expect, it } from 'vitest';
import { describeRepeat, dueOccurrence, formatCountdown, formatTime, nextEnabledAlarm, nextOccurrence } from '../src/core/schedule';
import { makeAlarm } from '../src/core/store';

// Wednesday 2026-11-25 06:59:30 local time
const WED = new Date(2026, 10, 25, 6, 59, 30);

describe('schedule', () => {
  it('finds the next occurrence later today', () => {
    const a = makeAlarm(0, { hour: 7, minute: 0, repeat: [] });
    expect(nextOccurrence(a, WED)).toEqual(new Date(2026, 10, 25, 7, 0));
  });

  it('skips to the next repeat day', () => {
    const a = makeAlarm(0, { hour: 6, minute: 0, repeat: [5] }); // Fridays
    expect(nextOccurrence(a, WED)).toEqual(new Date(2026, 10, 27, 6, 0));
  });

  it('rings once per occurrence and respects the catch-up window', () => {
    const a = makeAlarm(0, { hour: 7, minute: 0, repeat: [3] });
    const at = new Date(2026, 10, 25, 7, 0, 5);
    const key = dueOccurrence(a, at, []);
    expect(key).not.toBeNull();
    expect(dueOccurrence(a, at, [key!])).toBeNull();
    expect(dueOccurrence(a, new Date(2026, 10, 25, 7, 6), [])).toBeNull();
  });

  it('does not ring on days outside the repeat set or when disabled', () => {
    const at = new Date(2026, 10, 25, 7, 0, 5);
    expect(dueOccurrence(makeAlarm(0, { hour: 7, minute: 0, repeat: [1] }), at, [])).toBeNull();
    expect(dueOccurrence(makeAlarm(0, { hour: 7, minute: 0, repeat: [3], enabled: false }), at, [])).toBeNull();
  });

  it('does not fire a one-shot alarm for a time before it was created', () => {
    const created = new Date(2026, 10, 25, 7, 0, 30).getTime();
    const a = makeAlarm(created, { hour: 7, minute: 0, repeat: [] });
    expect(dueOccurrence(a, new Date(2026, 10, 25, 7, 1), [])).toBeNull();
  });

  it('picks the soonest enabled alarm', () => {
    const a = makeAlarm(0, { label: 'late', hour: 9, minute: 0, repeat: [] });
    const b = makeAlarm(0, { label: 'early', hour: 7, minute: 30, repeat: [] });
    const c = makeAlarm(0, { label: 'off', hour: 7, minute: 1, repeat: [], enabled: false });
    expect(nextEnabledAlarm([a, b, c], WED)?.alarm.label).toBe('early');
  });

  it('formats', () => {
    expect(formatTime(0, 5, false)).toBe('12:05 AM');
    expect(formatTime(13, 0, false)).toBe('1:00 PM');
    expect(formatTime(7, 9, true)).toBe('07:09');
    expect(formatCountdown(3_725_000)).toBe('1h 02m');
    expect(formatCountdown(65_000)).toBe('1m 05s');
    expect(describeRepeat([1, 2, 3, 4, 5])).toBe('Weekdays');
    expect(describeRepeat([])).toBe('Once');
  });
});
