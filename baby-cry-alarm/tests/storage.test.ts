import { describe, expect, it } from "vitest";
import { alarmFromSettings, DEFAULT_SETTINGS, defaultAlarm, load, parseAlarm, parseSaved, parseSettings, save, serialize, STORAGE_KEY } from "../src/storage";

function memoryStorage(init: Record<string, string> = {}) {
  const data = new Map(Object.entries(init));
  return {
    getItem: (k: string) => data.get(k) ?? null,
    setItem: (k: string, v: string) => void data.set(k, v),
    data,
  };
}

describe("first run", () => {
  it("seeds a weekday morning baby alarm", () => {
    const saved = load(memoryStorage());
    expect(saved.seeded).toBe(true);
    expect(saved.alarms).toHaveLength(1);
    const [a] = saved.alarms;
    expect(a).toMatchObject({ hour: 7, minute: 0, enabled: true, repeat: [1, 2, 3, 4, 5], voice: "newborn" });
  });

  it("does not re-seed once the user has deleted everything", () => {
    const store = memoryStorage({ [STORAGE_KEY]: serialize({ alarms: [], snoozes: [], seeded: true, settings: DEFAULT_SETTINGS }) });
    expect(load(store).alarms).toEqual([]);
  });

  it("survives unreadable storage", () => {
    expect(load(null).alarms).toHaveLength(1);
    expect(load(memoryStorage({ [STORAGE_KEY]: "{not json" })).alarms).toHaveLength(1);
  });
});

describe("round trip", () => {
  it("saves and loads alarms unchanged", () => {
    const store = memoryStorage();
    const a = defaultAlarm({ hour: 5, minute: 45, repeat: [0, 6], voice: "shuffle", mission: { kind: "typing", rounds: 2 } });
    save(store, { alarms: [a], snoozes: [{ alarmId: a.id, at: 123, count: 1 }], seeded: true, settings: DEFAULT_SETTINGS });
    const back = load(store);
    expect(back.alarms).toEqual([a]);
    expect(back.snoozes).toEqual([{ alarmId: a.id, at: 123, count: 1 }]);
  });
});

describe("validation", () => {
  it("drops malformed alarms and clamps values", () => {
    expect(parseAlarm({ id: "x", hour: 25, minute: 0 })).toBeNull();
    expect(parseAlarm("nope")).toBeNull();
    const a = parseAlarm({ id: "x", hour: 6, minute: 5, volume: 7, voice: "robot", repeat: [1, 1, 9], mission: { kind: "math", difficulty: 9 } })!;
    expect(a.volume).toBe(1);
    expect(a.voice).toBe("newborn");
    expect(a.repeat).toEqual([1]);
    expect(a.mission).toEqual({ kind: "none" });
  });

  it("drops snoozes for alarms that no longer exist", () => {
    const parsed = parseSaved(JSON.stringify({ alarms: [], snoozes: [{ alarmId: "gone", at: 1, count: 1 }], seeded: true, settings: DEFAULT_SETTINGS }));
    expect(parsed?.snoozes).toEqual([]);
  });
});

describe("settings", () => {
  it("defaults when missing or invalid", () => {
    expect(parseSettings(undefined)).toEqual(DEFAULT_SETTINGS);
    expect(parseSettings({ use24h: "yes", defaultVoice: "robot", defaultMission: "dance", defaultSnoozeMinutes: 99 })).toEqual({
      ...DEFAULT_SETTINGS,
      defaultSnoozeMinutes: 30,
    });
  });

  it("round-trips through storage", () => {
    const store = memoryStorage();
    const settings = { use24h: true, defaultVoice: "kunjappi" as const, defaultMission: "rock" as const, defaultSnoozeMinutes: 9 };
    save(store, { alarms: [], snoozes: [], seeded: true, settings });
    expect(load(store).settings).toEqual(settings);
  });

  it("new alarms follow the defaults", () => {
    const a = alarmFromSettings({ use24h: false, defaultVoice: "fussy", defaultMission: "math", defaultSnoozeMinutes: 8 }, { hour: 6 });
    expect(a.voice).toBe("fussy");
    expect(a.mission.kind).toBe("math");
    expect(a.snooze.minutes).toBe(8);
    expect(a.hour).toBe(6);
  });
});
