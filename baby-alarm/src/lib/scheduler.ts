import type { Alarm, Weekday } from "./types";

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * Next time (epoch ms, strictly after `from`) at which `alarm` should ring,
 * or null if the alarm is disabled.
 */
export function nextFireTime(alarm: Alarm, from: Date): number | null {
  if (!alarm.enabled) return null;
  for (let offset = 0; offset <= 7; offset++) {
    const candidate = new Date(from.getFullYear(), from.getMonth(), from.getDate() + offset, alarm.hour, alarm.minute, 0, 0);
    if (candidate.getTime() <= from.getTime()) continue;
    if (alarm.repeat.length === 0 || alarm.repeat.includes(candidate.getDay() as Weekday)) {
      return candidate.getTime();
    }
  }
  return null;
}

/** Earliest upcoming alarm across a list. */
export function nextAlarm(alarms: Alarm[], from: Date): { alarm: Alarm; at: number } | null {
  let best: { alarm: Alarm; at: number } | null = null;
  for (const alarm of alarms) {
    const at = nextFireTime(alarm, from);
    if (at !== null && (best === null || at < best.at)) best = { alarm, at };
  }
  return best;
}

/**
 * Alarms whose scheduled minute falls in the half-open window (prev, now].
 * The app calls this on every tick with the previous tick time, so an alarm
 * fires exactly once even if a tick is delayed (e.g. a throttled background tab).
 */
export function dueAlarms(alarms: Alarm[], prev: Date, now: Date): Alarm[] {
  if (now.getTime() <= prev.getTime()) return [];
  // Guard against huge gaps (device asleep for hours): only look back 10 minutes.
  const floor = new Date(Math.max(prev.getTime(), now.getTime() - 10 * 60 * 1000));
  return alarms.filter((a) => {
    const at = nextFireTime(a, floor);
    return at !== null && at <= now.getTime();
  });
}

export function formatCountdown(ms: number): string {
  if (ms < 0) ms = 0;
  const totalMin = Math.round(ms / 60000);
  const days = Math.floor(totalMin / (24 * 60));
  const hours = Math.floor((totalMin % (24 * 60)) / 60);
  const mins = totalMin % 60;
  if (days > 0) return `${days}d ${hours}h`;
  if (hours > 0) return `${hours}h ${mins}m`;
  return `${mins}m`;
}

export function formatTime(hour: number, minute: number, use24h: boolean): string {
  const mm = String(minute).padStart(2, "0");
  if (use24h) return `${String(hour).padStart(2, "0")}:${mm}`;
  const h12 = hour % 12 === 0 ? 12 : hour % 12;
  return `${h12}:${mm} ${hour < 12 ? "AM" : "PM"}`;
}

export const WEEKDAY_SHORT = ["S", "M", "T", "W", "T", "F", "S"] as const;
const WEEKDAY_NAMES = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"] as const;

export function describeRepeat(repeat: Weekday[]): string {
  if (repeat.length === 0) return "Once";
  const set = [...new Set(repeat)].sort();
  if (set.length === 7) return "Every day";
  if (set.length === 5 && [1, 2, 3, 4, 5].every((d) => set.includes(d as Weekday))) return "Weekdays";
  if (set.length === 2 && set.includes(0) && set.includes(6)) return "Weekends";
  return set.map((d) => WEEKDAY_NAMES[d]).join(" ");
}

export { DAY_MS };
