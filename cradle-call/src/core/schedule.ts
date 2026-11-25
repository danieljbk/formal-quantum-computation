import type { Alarm, Weekday } from './types';

export const WEEKDAY_SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'] as const;

/** How late (ms) an alarm may still fire if the page was throttled or asleep. */
export const CATCH_UP_WINDOW_MS = 5 * 60_000;

function atTime(base: Date, hour: number, minute: number): Date {
  const d = new Date(base);
  d.setHours(hour, minute, 0, 0);
  return d;
}

/** Next time strictly after `now` that this alarm is scheduled for (ignores `enabled`). */
export function nextOccurrence(alarm: Pick<Alarm, 'hour' | 'minute' | 'repeat'>, now: Date): Date {
  for (let offset = 0; offset <= 7; offset++) {
    const day = new Date(now);
    day.setDate(now.getDate() + offset);
    const candidate = atTime(day, alarm.hour, alarm.minute);
    if (candidate.getTime() <= now.getTime()) continue;
    if (alarm.repeat.length === 0 || alarm.repeat.includes(candidate.getDay() as Weekday)) return candidate;
  }
  // Unreachable for valid input (repeat is a subset of 0..6), but keep a sane fallback.
  return atTime(new Date(now.getTime() + 86_400_000), alarm.hour, alarm.minute);
}

/** Most recent scheduled time at or before `now` (today or yesterday), or null. */
export function latestOccurrence(alarm: Pick<Alarm, 'hour' | 'minute' | 'repeat'>, now: Date): Date | null {
  for (let offset = 0; offset <= 1; offset++) {
    const day = new Date(now);
    day.setDate(now.getDate() - offset);
    const candidate = atTime(day, alarm.hour, alarm.minute);
    if (candidate.getTime() > now.getTime()) continue;
    if (alarm.repeat.length === 0 || alarm.repeat.includes(candidate.getDay() as Weekday)) return candidate;
  }
  return null;
}

export function occurrenceKey(alarmId: string, at: Date): string {
  return `${alarmId}@${at.getFullYear()}-${at.getMonth() + 1}-${at.getDate()}T${at.getHours()}:${at.getMinutes()}`;
}

/** If the alarm should start ringing now, returns its occurrence key. */
export function dueOccurrence(alarm: Alarm, now: Date, firedKeys: readonly string[]): string | null {
  if (!alarm.enabled) return null;
  const at = latestOccurrence(alarm, now);
  if (!at) return null;
  if (alarm.repeat.length === 0 && at.getTime() < alarm.createdAt) return null;
  if (now.getTime() - at.getTime() > CATCH_UP_WINDOW_MS) return null;
  const key = occurrenceKey(alarm.id, at);
  return firedKeys.includes(key) ? null : key;
}

export function nextEnabledAlarm(alarms: readonly Alarm[], now: Date): { alarm: Alarm; at: Date } | null {
  let best: { alarm: Alarm; at: Date } | null = null;
  for (const alarm of alarms) {
    if (!alarm.enabled) continue;
    const at = nextOccurrence(alarm, now);
    if (!best || at < best.at) best = { alarm, at };
  }
  return best;
}

export function formatCountdown(ms: number): string {
  const total = Math.max(0, Math.round(ms / 1000));
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h}h ${String(m).padStart(2, '0')}m`;
  if (m > 0) return `${m}m ${String(s).padStart(2, '0')}s`;
  return `${s}s`;
}

export function formatTime(hour: number, minute: number, use24h: boolean): string {
  const mm = String(minute).padStart(2, '0');
  if (use24h) return `${String(hour).padStart(2, '0')}:${mm}`;
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${h12}:${mm} ${hour < 12 ? 'AM' : 'PM'}`;
}

export function describeRepeat(repeat: readonly Weekday[]): string {
  if (repeat.length === 0) return 'Once';
  if (repeat.length === 7) return 'Every day';
  const sorted = [...repeat].sort();
  if (sorted.join() === '1,2,3,4,5') return 'Weekdays';
  if (sorted.join() === '0,6') return 'Weekends';
  return sorted.map((d) => WEEKDAY_SHORT[d]).join(' ');
}
