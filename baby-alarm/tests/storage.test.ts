import { describe, expect, it } from "vitest";
import { STORAGE_KEY, defaultState, loadState, parseState, saveState } from "../src/lib/storage";

function memStorage() {
  const m = new Map<string, string>();
  return { getItem: (k: string) => m.get(k) ?? null, setItem: (k: string, v: string) => void m.set(k, v), m };
}

describe("persistence", () => {
  it("round-trips settings, alarms and history", () => {
    const s = defaultState();
    s.settings.volume = 0.5;
    s.settings.use24h = true;
    s.alarms[0].hour = 5;
    s.history.push({ id: "h", alarmId: "morning", alarmLabel: "Morning", firedAt: 1, dismissedAt: 61_000, snoozes: 1, challenge: "math", soundId: "wail-full-lungs", failedAttempts: 0 });
    const store = memStorage();
    expect(saveState(s, store)).toBe(true);
    const back = loadState(store);
    expect(back.settings.volume).toBe(0.5);
    expect(back.settings.use24h).toBe(true);
    expect(back.alarms[0].hour).toBe(5);
    expect(back.history).toHaveLength(1);
    expect(store.m.has(STORAGE_KEY)).toBe(true);
  });

  it("falls back to defaults on corrupt or foreign data", () => {
    expect(parseState("not json")).toEqual(expect.objectContaining({ version: 1 }));
    expect(parseState(JSON.stringify({ version: 99 })).alarms).toHaveLength(1);
    const clamped = parseState(JSON.stringify({ version: 1, settings: { volume: 7 }, alarms: [], history: [] }));
    expect(clamped.settings.volume).toBe(1);
  });

  it("survives a throwing storage", () => {
    const bad = { getItem: () => { throw new Error("denied"); }, setItem: () => { throw new Error("full"); } };
    expect(loadState(bad).version).toBe(1);
    expect(saveState(defaultState(), bad)).toBe(false);
  });
});
