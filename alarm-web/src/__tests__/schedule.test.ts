import { describe, expect, it } from 'vitest';
import { describeRepeat, formatCountdown, formatTime, isDue, nextOccurrence, nextRing, previousOccurrenceAtOrBefore } from '../schedule';
import { createAlarm } from '../storage';

// Wednesday 2026-11-25 06:30 local time.
const WED_0630 = new Date(2026, 10, 25, 6, 30).getTime();
const created = new Date(2026, 10, 1).getTime();

describe('nextOccurrence', () => {
  it('rings later today when the time has not passed', () => {
    const at = nextOccurrence(createAlarm({ hour: 7, minute: 0 }), WED_0630);
    expect(new Date(at)).toEqual(new Date(2026, 10, 25, 7, 0));
  });

  it('rolls to tomorrow when the time has passed', () => {
    const at = nextOccurrence(createAlarm({ hour: 6, minute: 0 }), WED_0630);
    expect(new Date(at)).toEqual(new Date(2026, 10, 26, 6, 0));
  });

  it('skips to the next selected weekday', () => {
    // Weekends only: next is Saturday the 28th.
    const at = nextOccurrence(createAlarm({ hour: 7, minute: 0, repeatDays: [0, 6] }), WED_0630);
    expect(new Date(at)).toEqual(new Date(2026, 10, 28, 7, 0));
  });

  it('wraps a full week for a single weekday already passed today', () => {
    const at = nextOccurrence(createAlarm({ hour: 6, minute: 0, repeatDays: [3] }), WED_0630);
    expect(new Date(at)).toEqual(new Date(2026, 11, 2, 6, 0));
  });

  it('uses the one-shot time for quick alarms', () => {
    const at = WED_0630 + 20 * 60_000;
    expect(nextOccurrence(createAlarm({ oneShotAt: at }), WED_0630)).toBe(at);
  });
});

describe('isDue', () => {
  const alarm = createAlarm({ hour: 6, minute: 30, createdAt: created });

  it('is due at the exact minute', () => {
    expect(isDue(alarm, WED_0630)).toBe(true);
  });

  it('is due within the grace window but not after', () => {
    expect(isDue(alarm, WED_0630 + 4 * 60_000)).toBe(true);
    expect(isDue(alarm, WED_0630 + 6 * 60_000)).toBe(false);
  });

  it('does not double-fire after it has fired', () => {
    expect(isDue({ ...alarm, lastFiredAt: WED_0630 }, WED_0630 + 30_000)).toBe(false);
  });

  it('ignores disabled alarms and non-selected weekdays', () => {
    expect(isDue({ ...alarm, enabled: false }, WED_0630)).toBe(false);
    expect(isDue({ ...alarm, repeatDays: [1] }, WED_0630)).toBe(false);
  });

  it('never fires for an occurrence before the alarm existed', () => {
    expect(isDue({ ...alarm, createdAt: WED_0630 + 1 }, WED_0630 + 60_000)).toBe(false);
  });
});

describe('previousOccurrenceAtOrBefore', () => {
  it('finds the most recent matching weekday', () => {
    const a = createAlarm({ hour: 7, minute: 0, repeatDays: [1], createdAt: created });
    expect(new Date(previousOccurrenceAtOrBefore(a, WED_0630)!)).toEqual(new Date(2026, 10, 23, 7, 0));
  });
});

describe('nextRing', () => {
  it('picks the earliest enabled alarm', () => {
    const a = createAlarm({ hour: 9, minute: 0 });
    const b = createAlarm({ hour: 7, minute: 15 });
    const c = createAlarm({ hour: 6, minute: 45, enabled: false });
    expect(nextRing([a, b, c], WED_0630)?.alarm).toBe(b);
    expect(nextRing([c], WED_0630)).toBeNull();
  });
});

describe('formatting', () => {
  it('formats countdowns', () => {
    expect(formatCountdown(30_000)).toBe('Rings in 1 min');
    expect(formatCountdown((7 * 60 + 32) * 60_000)).toBe('Rings in 7 h 32 min');
    expect(formatCountdown(26 * 60 * 60_000)).toBe('Rings in 1 d 2 h');
  });

  it('formats 12 and 24 hour times', () => {
    expect(formatTime(0, 5, false)).toEqual({ time: '12:05', meridiem: 'AM' });
    expect(formatTime(13, 0, false)).toEqual({ time: '1:00', meridiem: 'PM' });
    expect(formatTime(7, 9, true)).toEqual({ time: '07:09', meridiem: '' });
  });

  it('describes repeat sets like iOS', () => {
    expect(describeRepeat([])).toBe('Once');
    expect(describeRepeat([1, 2, 3, 4, 5])).toBe('Weekdays');
    expect(describeRepeat([0, 6])).toBe('Weekends');
    expect(describeRepeat([0, 1, 2, 3, 4, 5, 6])).toBe('Every day');
    expect(describeRepeat([1, 3])).toBe('Mon Wed');
  });
});
