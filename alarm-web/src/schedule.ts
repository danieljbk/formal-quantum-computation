import type { Alarm, Weekday } from './types';

export const WEEKDAY_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const;
export const WEEKDAYS: readonly Weekday[] = [0, 1, 2, 3, 4, 5, 6];
const ONE_MINUTE = 60_000;

/**
 * The next time (ms since epoch) strictly after `from` at which `alarm` should ring,
 * ignoring whether it is enabled. Uses local time, so DST shifts are handled by `Date`.
 */
export function nextOccurrence(alarm: Pick<Alarm, 'hour' | 'minute' | 'repeatDays' | 'oneShotAt'>, from: number): number {
  if (alarm.oneShotAt !== undefined) return alarm.oneShotAt;
  const start = new Date(from);
  for (let offset = 0; offset <= 7; offset++) {
    const candidate = new Date(
      start.getFullYear(),
      start.getMonth(),
      start.getDate() + offset,
      alarm.hour,
      alarm.minute,
      0,
      0,
    );
    if (candidate.getTime() <= from) continue;
    if (alarm.repeatDays.length === 0 || alarm.repeatDays.includes(candidate.getDay() as Weekday)) {
      return candidate.getTime();
    }
  }
  // Unreachable for valid input: every weekday appears within 8 days.
  throw new Error('No occurrence found within a week');
}

/** The earliest upcoming ring among enabled alarms, or `null` if none are on. */
export function nextRing(alarms: Alarm[], from: number): { alarm: Alarm; at: number } | null {
  let best: { alarm: Alarm; at: number } | null = null;
  for (const alarm of alarms) {
    if (!alarm.enabled) continue;
    const at = nextOccurrence(alarm, from);
    if (!best || at < best.at) best = { alarm, at };
  }
  return best;
}

/**
 * Whether `alarm` is due at `now`: it is enabled, its time has arrived within the last
 * `graceMs` (so a backgrounded tab that wakes late still rings), and it has not already
 * fired for this occurrence.
 */
export function isDue(alarm: Alarm, now: number, graceMs = 5 * ONE_MINUTE): boolean {
  if (!alarm.enabled) return false;
  const occurrence = previousOccurrenceAtOrBefore(alarm, now);
  if (occurrence === null) return false;
  if (now - occurrence > graceMs) return false;
  return alarm.lastFiredAt === undefined || alarm.lastFiredAt < occurrence;
}

/** The most recent scheduled time at or before `now`, within the last 8 days. */
export function previousOccurrenceAtOrBefore(
  alarm: Pick<Alarm, 'hour' | 'minute' | 'repeatDays' | 'oneShotAt' | 'createdAt'>,
  now: number,
): number | null {
  if (alarm.oneShotAt !== undefined) return alarm.oneShotAt <= now ? alarm.oneShotAt : null;
  const base = new Date(now);
  for (let offset = 0; offset <= 7; offset++) {
    const candidate = new Date(
      base.getFullYear(),
      base.getMonth(),
      base.getDate() - offset,
      alarm.hour,
      alarm.minute,
      0,
      0,
    );
    const t = candidate.getTime();
    if (t > now) continue;
    if (t < alarm.createdAt) return null;
    if (alarm.repeatDays.length === 0 || alarm.repeatDays.includes(candidate.getDay() as Weekday)) {
      return t;
    }
  }
  return null;
}

/** "Rings in 7 h 32 min" style countdown text. */
export function formatCountdown(ms: number): string {
  const totalMinutes = Math.max(1, Math.ceil(ms / ONE_MINUTE));
  const days = Math.floor(totalMinutes / (24 * 60));
  const hours = Math.floor((totalMinutes % (24 * 60)) / 60);
  const minutes = totalMinutes % 60;
  const parts: string[] = [];
  if (days) parts.push(`${days} d`);
  if (hours) parts.push(`${hours} h`);
  if (minutes || parts.length === 0) parts.push(`${minutes} min`);
  return `Rings in ${parts.join(' ')}`;
}

export function formatTime(hour: number, minute: number, use24h: boolean): { time: string; meridiem: string } {
  const mm = String(minute).padStart(2, '0');
  if (use24h) return { time: `${String(hour).padStart(2, '0')}:${mm}`, meridiem: '' };
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  return { time: `${h12}:${mm}`, meridiem: hour < 12 ? 'AM' : 'PM' };
}

/** Human summary of the repeat set, as the iOS Clock app phrases it. */
export function describeRepeat(days: Weekday[]): string {
  if (days.length === 0) return 'Once';
  const set = new Set(days);
  if (set.size === 7) return 'Every day';
  if (set.size === 5 && [1, 2, 3, 4, 5].every((d) => set.has(d as Weekday))) return 'Weekdays';
  if (set.size === 2 && set.has(0) && set.has(6)) return 'Weekends';
  return WEEKDAYS.filter((d) => set.has(d)).map((d) => WEEKDAY_SHORT[d]).join(' ');
}
