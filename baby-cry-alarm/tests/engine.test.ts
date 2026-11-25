import { describe, expect, it } from "vitest";
import { canSnooze, dismiss, removeAlarm, ringNow, skipNext, snooze, snoozesLeft, tick, type ClockState } from "../src/engine";
import { makeRng } from "../src/missions";
import { SOUND_IDS } from "../src/sounds";
import { defaultAlarm } from "../src/storage";

const at = (h: number, min: number, d = 25) => new Date(2026, 10, d, h, min, 0, 0).getTime();

function state(over: Partial<ClockState> = {}): ClockState {
  return { alarms: [], snoozes: [], ringing: null, lastCheck: at(6, 59), ...over };
}

describe("tick", () => {
  it("starts the baby crying when the alarm time passes", () => {
    const a = defaultAlarm({ id: "m", hour: 7, minute: 0, voice: "hungry", repeat: [3] });
    const s = tick(state({ alarms: [a] }), at(7, 0) + 400);
    expect(s.ringing).toMatchObject({ alarmId: "m", firedAt: at(7, 0), soundId: "hungry", snoozeCount: 0 });
    expect(s.alarms[0].enabled).toBe(true); // repeating alarms stay on
  });

  it("switches one-off alarms off after they ring", () => {
    const a = defaultAlarm({ id: "o", hour: 7, minute: 0 });
    const s = tick(state({ alarms: [a] }), at(7, 0) + 1);
    expect(s.ringing?.alarmId).toBe("o");
    expect(s.alarms[0].enabled).toBe(false);
  });

  it("does nothing before the alarm time", () => {
    const a = defaultAlarm({ id: "m", hour: 7, minute: 0 });
    const s = tick(state({ alarms: [a] }), at(6, 59) + 30_000);
    expect(s.ringing).toBeNull();
  });

  it("resolves the surprise baby to a real recording", () => {
    const a = defaultAlarm({ id: "m", hour: 7, minute: 0, voice: "shuffle" });
    const s = tick(state({ alarms: [a] }), at(7, 0) + 1, makeRng(3));
    expect(SOUND_IDS).toContain(s.ringing!.soundId);
  });
});

describe("snooze and dismiss", () => {
  const a = defaultAlarm({ id: "m", hour: 7, minute: 0, repeat: [3], snooze: { enabled: true, minutes: 5, maxCount: 2 } });

  it("snoozes, re-rings after the interval, and runs out", () => {
    let s = tick(state({ alarms: [a] }), at(7, 0) + 1);
    expect(snoozesLeft(s)).toBe(2);

    s = snooze(s, at(7, 1));
    expect(s.ringing).toBeNull();
    expect(s.snoozes).toEqual([{ alarmId: "m", at: at(7, 6), count: 1 }]);

    s = tick(s, at(7, 6) + 1);
    expect(s.ringing).toMatchObject({ alarmId: "m", snoozeCount: 1 });
    expect(s.snoozes).toEqual([]);
    expect(snoozesLeft(s)).toBe(1);

    s = tick(snooze(s, at(7, 7)), at(7, 12) + 1);
    expect(s.ringing?.snoozeCount).toBe(2);
    expect(canSnooze(s)).toBe(false);
    expect(snooze(s, at(7, 13))).toBe(s); // refused
  });

  it("dismiss stops ringing and clears pending snoozes", () => {
    let s = tick(state({ alarms: [a] }), at(7, 0) + 1);
    s = dismiss(s, at(7, 2));
    expect(s.ringing).toBeNull();
    expect(s.snoozes).toEqual([]);
    // Nothing else rings this morning.
    expect(tick(s, at(7, 30)).ringing).toBeNull();
  });

  it("refuses snooze when snooze is disabled", () => {
    const noSnooze = { ...a, snooze: { ...a.snooze, enabled: false } };
    const s = tick(state({ alarms: [noSnooze] }), at(7, 0) + 1);
    expect(canSnooze(s)).toBe(false);
  });
});

describe("skipNext, removeAlarm, ringNow", () => {
  it("skipNext silences only the next occurrence", () => {
    const a = defaultAlarm({ id: "d", hour: 7, minute: 0, repeat: [0, 1, 2, 3, 4, 5, 6] });
    let s = skipNext(state({ alarms: [a] }), "d", at(6, 0));
    s = tick(s, at(7, 1));
    expect(s.ringing).toBeNull();
    s = tick(s, at(7, 0, 26) + 1);
    expect(s.ringing?.alarmId).toBe("d");
  });

  it("removing a ringing alarm stops it", () => {
    const a = defaultAlarm({ id: "r" });
    const s = removeAlarm(ringNow(state({ alarms: [a] }), "r", at(6, 0)), "r");
    expect(s.ringing).toBeNull();
    expect(s.alarms).toEqual([]);
  });
});
