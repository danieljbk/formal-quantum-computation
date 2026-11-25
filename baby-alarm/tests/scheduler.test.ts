import { describe, expect, it } from "vitest";
import { describeRepeat, dueAlarms, formatCountdown, formatTime, nextAlarm, nextFireTime } from "../src/lib/scheduler";
import { DEFAULT_SETTINGS, newAlarm } from "../src/lib/storage";

const mk = (p: Parameters<typeof newAlarm>[1]) => newAlarm(DEFAULT_SETTINGS, p);
// Wednesday 25 Nov 2026, 06:30 local
const wed0630 = new Date(2026, 10, 25, 6, 30, 0);

describe("nextFireTime", () => {
  it("fires later the same day for a one-shot alarm", () => {
    const a = mk({ hour: 7, minute: 0, repeat: [] });
    expect(nextFireTime(a, wed0630)).toBe(new Date(2026, 10, 25, 7, 0).getTime());
  });
  it("rolls to tomorrow when the time has passed", () => {
    const a = mk({ hour: 6, minute: 0, repeat: [] });
    expect(nextFireTime(a, wed0630)).toBe(new Date(2026, 10, 26, 6, 0).getTime());
  });
  it("respects repeat days (weekend alarm from a Wednesday)", () => {
    const a = mk({ hour: 9, minute: 0, repeat: [0, 6] });
    expect(new Date(nextFireTime(a, wed0630)!).getDay()).toBe(6);
  });
  it("returns null when disabled", () => {
    expect(nextFireTime(mk({ enabled: false }), wed0630)).toBeNull();
  });
  it("is strictly after `from`", () => {
    const a = mk({ hour: 6, minute: 30, repeat: [] });
    expect(nextFireTime(a, wed0630)).toBe(new Date(2026, 10, 26, 6, 30).getTime());
  });
});

describe("dueAlarms", () => {
  it("fires an alarm whose minute is crossed between ticks, exactly once", () => {
    const a = mk({ hour: 6, minute: 31, repeat: [] });
    const t1 = new Date(2026, 10, 25, 6, 30, 59);
    const t2 = new Date(2026, 10, 25, 6, 31, 0);
    const t3 = new Date(2026, 10, 25, 6, 31, 1);
    expect(dueAlarms([a], t1, t2)).toEqual([a]);
    expect(dueAlarms([a], t2, t3)).toEqual([]);
  });
  it("catches alarms during a delayed tick but not ancient ones", () => {
    const a = mk({ hour: 6, minute: 31, repeat: [] });
    expect(dueAlarms([a], new Date(2026, 10, 25, 6, 29), new Date(2026, 10, 25, 6, 35))).toHaveLength(1);
    expect(dueAlarms([a], new Date(2026, 10, 25, 1, 0), new Date(2026, 10, 25, 7, 0))).toHaveLength(0);
  });
});

describe("helpers", () => {
  it("picks the earliest upcoming alarm", () => {
    const a = mk({ hour: 8, minute: 0, repeat: [] });
    const b = mk({ hour: 7, minute: 15, repeat: [] });
    expect(nextAlarm([a, b], wed0630)?.alarm).toBe(b);
  });
  it("formats times and countdowns", () => {
    expect(formatTime(0, 5, false)).toBe("12:05 AM");
    expect(formatTime(13, 0, false)).toBe("1:00 PM");
    expect(formatTime(7, 9, true)).toBe("07:09");
    expect(formatCountdown(90 * 60_000)).toBe("1h 30m");
    expect(formatCountdown(26 * 3600_000)).toBe("1d 2h");
  });
  it("describes repeat sets", () => {
    expect(describeRepeat([])).toBe("Once");
    expect(describeRepeat([1, 2, 3, 4, 5])).toBe("Weekdays");
    expect(describeRepeat([0, 6])).toBe("Weekends");
    expect(describeRepeat([0, 1, 2, 3, 4, 5, 6])).toBe("Every day");
    expect(describeRepeat([1, 3])).toBe("Mon Wed");
  });
});
