import { describe, expect, it } from "vitest";
import { computeStats, formatDuration } from "../src/lib/analytics";
import type { WakeRecord } from "../src/lib/types";

const rec = (day: number, secs: number, snoozes = 0): WakeRecord => {
  const fired = new Date(2026, 10, day, 7, 0).getTime();
  return { id: `${day}`, alarmId: "a", alarmLabel: "A", firedAt: fired, dismissedAt: fired + secs * 1000, snoozes, challenge: "math", soundId: "x", failedAttempts: 0 };
};

describe("computeStats", () => {
  const now = new Date(2026, 10, 25, 12, 0);
  it("computes streak, averages and no-snooze rate", () => {
    const s = computeStats([rec(23, 30), rec(24, 60, 2), rec(25, 90)], now);
    expect(s.total).toBe(3);
    expect(s.streak).toBe(3);
    expect(s.avgSecondsToDismiss).toBe(60);
    expect(s.avgSnoozes).toBe(0.7);
    expect(s.noSnoozeRate).toBeCloseTo(2 / 3);
    expect(s.last7Days).toHaveLength(7);
    expect(s.last7Days[6].seconds).toBe(90);
    expect(s.last7Days[0].seconds).toBeNull();
  });
  it("keeps the streak alive if today has no wake-up yet, and breaks on gaps", () => {
    expect(computeStats([rec(23, 10), rec(24, 10)], now).streak).toBe(2);
    expect(computeStats([rec(21, 10), rec(24, 10)], now).streak).toBe(1);
    expect(computeStats([], now).streak).toBe(0);
  });
  it("formats durations", () => {
    expect(formatDuration(42)).toBe("42s");
    expect(formatDuration(120)).toBe("2m");
    expect(formatDuration(135)).toBe("2m 15s");
  });
});
