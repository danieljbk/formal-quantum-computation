import { describe, expect, it } from "vitest";
import { describeRepeat, dueInWindow, formatClock, formatCountdown, nextOccurrence, nextRing } from "../src/schedule";
import { defaultAlarm } from "../src/storage";

// Local-time helper: new Date(y, m, d, h, min).
const at = (y: number, m: number, d: number, h = 0, min = 0) => new Date(y, m - 1, d, h, min, 0, 0).getTime();

// 2026-11-25 is a Wednesday.
const WED_6AM = at(2026, 11, 25, 6, 0);

describe("nextOccurrence", () => {
  it("rings later today for a one-off alarm", () => {
    const a = defaultAlarm({ hour: 7, minute: 30 });
    expect(nextOccurrence(a, WED_6AM)).toBe(at(2026, 11, 25, 7, 30));
  });

  it("rolls to tomorrow when today's time has passed", () => {
    const a = defaultAlarm({ hour: 5, minute: 0 });
    expect(nextOccurrence(a, WED_6AM)).toBe(at(2026, 11, 26, 5, 0));
  });

  it("is strictly after the reference time", () => {
    const a = defaultAlarm({ hour: 6, minute: 0 });
    expect(nextOccurrence(a, WED_6AM)).toBe(at(2026, 11, 26, 6, 0));
  });

  it("honours repeat days (weekdays from Friday evening -> Monday)", () => {
    const a = defaultAlarm({ hour: 7, minute: 0, repeat: [1, 2, 3, 4, 5] });
    expect(nextOccurrence(a, at(2026, 11, 27, 20, 0))).toBe(at(2026, 11, 30, 7, 0));
  });

  it("finds the same weekday next week", () => {
    const a = defaultAlarm({ hour: 5, minute: 0, repeat: [3] }); // Wednesdays
    expect(nextOccurrence(a, WED_6AM)).toBe(at(2026, 12, 2, 5, 0));
  });

  it("returns null when disabled", () => {
    expect(nextOccurrence(defaultAlarm({ enabled: false }), WED_6AM)).toBeNull();
  });

  it("uses fireAt for quick alarms and expires them", () => {
    const a = defaultAlarm({ fireAt: WED_6AM + 10 * 60_000 });
    expect(nextOccurrence(a, WED_6AM)).toBe(WED_6AM + 10 * 60_000);
    expect(nextOccurrence(a, WED_6AM + 11 * 60_000)).toBeNull();
  });

  it("skipUntil skips exactly one occurrence", () => {
    const a = defaultAlarm({ hour: 7, minute: 0, repeat: [0, 1, 2, 3, 4, 5, 6] });
    const first = nextOccurrence(a, WED_6AM)!;
    const skipped = { ...a, skipUntil: first + 1 };
    expect(nextOccurrence(skipped, WED_6AM)).toBe(at(2026, 11, 26, 7, 0));
  });
});

describe("dueInWindow", () => {
  it("catches an alarm whose time fell inside a throttled gap", () => {
    const a = defaultAlarm({ id: "x", hour: 7, minute: 0 });
    const due = dueInWindow([a], [], at(2026, 11, 25, 6, 59), at(2026, 11, 25, 7, 3));
    expect(due).toEqual([{ alarmId: "x", at: at(2026, 11, 25, 7, 0), snoozeCount: 0 }]);
  });

  it("does not fire outside the window", () => {
    const a = defaultAlarm({ id: "x", hour: 7, minute: 0 });
    expect(dueInWindow([a], [], at(2026, 11, 25, 7, 0), at(2026, 11, 25, 7, 5))).toEqual([]);
  });

  it("reports snoozes with their count", () => {
    const a = defaultAlarm({ id: "x", hour: 7, minute: 0 });
    const due = dueInWindow([a], [{ alarmId: "x", at: at(2026, 11, 25, 7, 5), count: 1 }], at(2026, 11, 25, 7, 4), at(2026, 11, 25, 7, 6));
    expect(due).toEqual([{ alarmId: "x", at: at(2026, 11, 25, 7, 5), snoozeCount: 1 }]);
  });
});

describe("nextRing", () => {
  it("picks the soonest of alarms and snoozes", () => {
    const a = defaultAlarm({ id: "a", hour: 7, minute: 0 });
    const b = defaultAlarm({ id: "b", hour: 6, minute: 30 });
    expect(nextRing([a, b], [], WED_6AM)).toEqual({ alarmId: "b", at: at(2026, 11, 25, 6, 30) });
    expect(nextRing([a, b], [{ alarmId: "a", at: WED_6AM + 60_000, count: 1 }], WED_6AM)).toEqual({
      alarmId: "a",
      at: WED_6AM + 60_000,
    });
  });
});

describe("formatting", () => {
  it("formats 12-hour clock", () => {
    expect(formatClock(0, 5)).toEqual({ time: "12:05", meridiem: "AM" });
    expect(formatClock(12, 0)).toEqual({ time: "12:00", meridiem: "PM" });
    expect(formatClock(19, 45)).toEqual({ time: "7:45", meridiem: "PM" });
    expect(formatClock(7, 5, true)).toEqual({ time: "07:05", meridiem: "" });
    expect(formatClock(19, 45, true)).toEqual({ time: "19:45", meridiem: "" });
  });

  it("formats countdowns", () => {
    expect(formatCountdown(30_000)).toBe("in less than a minute");
    expect(formatCountdown(45 * 60_000)).toBe("in 45 min");
    expect(formatCountdown((7 * 60 + 12) * 60_000)).toBe("in 7 h 12 min");
    expect(formatCountdown((26 * 60 + 5) * 60_000)).toBe("in 1 d 2 h");
  });

  it("describes repeat sets", () => {
    expect(describeRepeat([])).toBe("Once");
    expect(describeRepeat([1, 2, 3, 4, 5])).toBe("Weekdays");
    expect(describeRepeat([6, 0])).toBe("Weekends");
    expect(describeRepeat([0, 1, 2, 3, 4, 5, 6])).toBe("Every day");
    expect(describeRepeat([0, 1, 3])).toBe("Mon Wed Sun");
  });
});
