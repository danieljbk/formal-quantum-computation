import type { WakeRecord } from "./types";

export interface WakeStats {
  total: number;
  /** consecutive calendar days (ending today or yesterday) with at least one wake-up */
  streak: number;
  avgSecondsToDismiss: number;
  avgSnoozes: number;
  /** share of wake-ups with zero snoozes, 0..1 */
  noSnoozeRate: number;
  /** 7 entries, oldest first, ending with the day of `now` */
  last7Days: { label: string; seconds: number | null }[];
}

export function dayKey(ms: number): string {
  const d = new Date(ms);
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

export function secondsToDismiss(r: WakeRecord): number {
  return Math.max(0, Math.round((r.dismissedAt - r.firedAt) / 1000));
}

export function computeStats(history: WakeRecord[], now: Date): WakeStats {
  const total = history.length;
  const days = new Set(history.map((r) => dayKey(r.dismissedAt)));

  let streak = 0;
  const cursor = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (!days.has(dayKey(cursor.getTime()))) cursor.setDate(cursor.getDate() - 1);
  while (days.has(dayKey(cursor.getTime()))) {
    streak++;
    cursor.setDate(cursor.getDate() - 1);
  }

  const sum = (xs: number[]) => xs.reduce((a, b) => a + b, 0);
  const avgSecondsToDismiss = total ? Math.round(sum(history.map(secondsToDismiss)) / total) : 0;
  const avgSnoozes = total ? Math.round((sum(history.map((r) => r.snoozes)) / total) * 10) / 10 : 0;
  const noSnoozeRate = total ? history.filter((r) => r.snoozes === 0).length / total : 0;

  const names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"];
  const last7Days: WakeStats["last7Days"] = [];
  for (let i = 6; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth(), now.getDate() - i);
    const key = dayKey(d.getTime());
    const recs = history.filter((r) => dayKey(r.dismissedAt) === key);
    last7Days.push({
      label: names[d.getDay()],
      seconds: recs.length ? Math.round(sum(recs.map(secondsToDismiss)) / recs.length) : null,
    });
  }

  return { total, streak, avgSecondsToDismiss, avgSnoozes, noSnoozeRate, last7Days };
}

export function formatDuration(seconds: number): string {
  if (seconds < 60) return `${seconds}s`;
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return s ? `${m}m ${s}s` : `${m}m`;
}
