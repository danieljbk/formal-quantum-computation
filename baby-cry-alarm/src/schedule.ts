import type { Alarm, Snooze, Weekday } from "./types";

const DAY_SHORT = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as const;
const WEEKDAYS: Weekday[] = [1, 2, 3, 4, 5];
const WEEKEND: Weekday[] = [0, 6];

/**
 * The first time strictly after `after` at which `alarm` rings, or null if it
 * never will (disabled, or a one-off quick alarm that is already in the past).
 * Works in local time, so DST changes keep the wall-clock time.
 */
export function nextOccurrence(alarm: Alarm, after: number): number | null {
  if (!alarm.enabled) return null;
  // Occurrences must be > floor; skipUntil means "nothing before skipUntil".
  const floor = alarm.skipUntil !== undefined ? Math.max(after, alarm.skipUntil - 1) : after;

  if (alarm.fireAt !== undefined) {
    return alarm.fireAt > floor ? alarm.fireAt : null;
  }

  const base = new Date(floor);
  // Eight days covers "later today" through "same weekday next week".
  for (let i = 0; i <= 8; i++) {
    const candidate = new Date(
      base.getFullYear(),
      base.getMonth(),
      base.getDate() + i,
      alarm.hour,
      alarm.minute,
      0,
      0,
    );
    const t = candidate.getTime();
    if (t <= floor) continue;
    if (alarm.repeat.length === 0 || alarm.repeat.includes(candidate.getDay() as Weekday)) {
      return t;
    }
  }
  return null;
}

/** The soonest upcoming ring across all alarms and pending snoozes. */
export function nextRing(
  alarms: Alarm[],
  snoozes: Snooze[],
  now: number,
): { alarmId: string; at: number } | null {
  let best: { alarmId: string; at: number } | null = null;
  for (const a of alarms) {
    const at = nextOccurrence(a, now);
    if (at !== null && (best === null || at < best.at)) best = { alarmId: a.id, at };
  }
  for (const s of snoozes) {
    if (s.at > now && (best === null || s.at < best.at)) best = { alarmId: s.alarmId, at: s.at };
  }
  return best;
}

/**
 * Alarms that came due in the window (from, to]. Tabs can be throttled in the
 * background, so the caller passes the last time it checked rather than
 * assuming one-second ticks. Each alarm is reported at most once, at its
 * latest due time in the window.
 */
export function dueInWindow(
  alarms: Alarm[],
  snoozes: Snooze[],
  from: number,
  to: number,
): { alarmId: string; at: number; snoozeCount: number }[] {
  const due = new Map<string, { alarmId: string; at: number; snoozeCount: number }>();
  for (const a of alarms) {
    let at = nextOccurrence(a, from);
    let last: number | null = null;
    while (at !== null && at <= to) {
      last = at;
      at = nextOccurrence(a, at);
    }
    if (last !== null) due.set(a.id, { alarmId: a.id, at: last, snoozeCount: 0 });
  }
  for (const s of snoozes) {
    if (s.at > from && s.at <= to) {
      const prev = due.get(s.alarmId);
      if (!prev || s.at >= prev.at) due.set(s.alarmId, { alarmId: s.alarmId, at: s.at, snoozeCount: s.count });
    }
  }
  return [...due.values()].sort((x, y) => x.at - y.at);
}

export function formatClock(hour: number, minute: number): { time: string; meridiem: "AM" | "PM" } {
  const meridiem = hour < 12 ? "AM" : "PM";
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  return { time: `${h12}:${String(minute).padStart(2, "0")}`, meridiem };
}

/** "in 7 h 12 min", "in 45 min", "in less than a minute". */
export function formatCountdown(ms: number): string {
  if (ms < 60_000) return "in less than a minute";
  const totalMin = Math.floor(ms / 60_000);
  const days = Math.floor(totalMin / 1440);
  const hours = Math.floor((totalMin % 1440) / 60);
  const mins = totalMin % 60;
  const parts: string[] = [];
  if (days) parts.push(`${days} d`);
  if (hours) parts.push(`${hours} h`);
  if (mins && !days) parts.push(`${mins} min`);
  return `in ${parts.join(" ")}`;
}

export function describeRepeat(repeat: Weekday[]): string {
  const set = [...new Set(repeat)].sort((a, b) => a - b);
  if (set.length === 0) return "Once";
  if (set.length === 7) return "Every day";
  if (set.length === 5 && WEEKDAYS.every((d) => set.includes(d))) return "Weekdays";
  if (set.length === 2 && WEEKEND.every((d) => set.includes(d))) return "Weekends";
  // Monday-first reading order.
  return [...set]
    .sort((a, b) => ((a + 6) % 7) - ((b + 6) % 7))
    .map((d) => DAY_SHORT[d])
    .join(" ");
}

export function describeAlarmTime(alarm: Alarm): { time: string; meridiem: string } {
  if (alarm.fireAt !== undefined) {
    const d = new Date(alarm.fireAt);
    return formatClock(d.getHours(), d.getMinutes());
  }
  return formatClock(alarm.hour, alarm.minute);
}

export { DAY_SHORT };
