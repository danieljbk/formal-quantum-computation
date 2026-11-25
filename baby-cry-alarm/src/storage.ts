import { isVoiceChoice } from "./sounds";
import type { Alarm, Mission, Snooze, Weekday } from "./types";

export const STORAGE_KEY = "baby-cry-alarm/v1";

export interface Saved {
  alarms: Alarm[];
  snoozes: Snooze[];
  /** True once the first-run morning alarm has been created. */
  seeded: boolean;
}

let counter = 0;
export function newId(now: number = Date.now()): string {
  counter = (counter + 1) % 1_000_000;
  return `a${now.toString(36)}${counter.toString(36)}${Math.floor(Math.random() * 1296).toString(36)}`;
}

export function defaultAlarm(overrides: Partial<Alarm> = {}): Alarm {
  return {
    id: newId(),
    hour: 7,
    minute: 0,
    label: "",
    enabled: true,
    repeat: [],
    voice: "newborn",
    volume: 0.9,
    rampSeconds: 30,
    vibrate: true,
    snooze: { enabled: true, minutes: 5, maxCount: 3 },
    mission: { kind: "none" },
    ...overrides,
  };
}

/** The alarm every new install starts with: weekday mornings at 7:00. */
export function morningAlarm(): Alarm {
  return defaultAlarm({
    label: "Good morning",
    repeat: [1, 2, 3, 4, 5],
    voice: "newborn",
    mission: { kind: "math", difficulty: 1, rounds: 2 },
  });
}

const clamp = (n: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, n));
const isInt = (n: unknown): n is number => typeof n === "number" && Number.isInteger(n);

function parseMission(x: unknown): Mission {
  const m = x as Record<string, unknown> | null;
  if (!m || typeof m !== "object") return { kind: "none" };
  if (m.kind === "math" && (m.difficulty === 1 || m.difficulty === 2 || m.difficulty === 3) && isInt(m.rounds)) {
    return { kind: "math", difficulty: m.difficulty, rounds: clamp(m.rounds, 1, 10) };
  }
  if (m.kind === "typing" && isInt(m.rounds)) return { kind: "typing", rounds: clamp(m.rounds, 1, 5) };
  if (m.kind === "rock" && isInt(m.rocks)) return { kind: "rock", rocks: clamp(m.rocks, 5, 100) };
  return { kind: "none" };
}

/** Validate one stored alarm; anything malformed is dropped rather than crashing the app. */
export function parseAlarm(x: unknown): Alarm | null {
  const a = x as Record<string, unknown> | null;
  if (!a || typeof a !== "object") return null;
  if (typeof a.id !== "string" || !isInt(a.hour) || !isInt(a.minute)) return null;
  if (a.hour < 0 || a.hour > 23 || a.minute < 0 || a.minute > 59) return null;
  const repeat = Array.isArray(a.repeat)
    ? ([...new Set(a.repeat.filter((d) => isInt(d) && d >= 0 && d <= 6))] as Weekday[])
    : [];
  const s = (a.snooze ?? {}) as Record<string, unknown>;
  const alarm: Alarm = {
    id: a.id,
    hour: a.hour,
    minute: a.minute,
    label: typeof a.label === "string" ? a.label.slice(0, 40) : "",
    enabled: a.enabled !== false,
    repeat,
    voice: isVoiceChoice(a.voice) ? a.voice : "newborn",
    volume: typeof a.volume === "number" ? clamp(a.volume, 0.1, 1) : 0.9,
    rampSeconds: isInt(a.rampSeconds) ? clamp(a.rampSeconds, 0, 120) : 30,
    vibrate: a.vibrate !== false,
    snooze: {
      enabled: s.enabled !== false,
      minutes: isInt(s.minutes) ? clamp(s.minutes, 1, 30) : 5,
      maxCount: isInt(s.maxCount) ? clamp(s.maxCount, 1, 10) : 3,
    },
    mission: parseMission(a.mission),
  };
  if (isInt(a.fireAt)) alarm.fireAt = a.fireAt;
  if (isInt(a.skipUntil)) alarm.skipUntil = a.skipUntil;
  return alarm;
}

export function parseSaved(raw: string | null): Saved | null {
  if (!raw) return null;
  try {
    const data = JSON.parse(raw) as Record<string, unknown>;
    const alarms = Array.isArray(data.alarms) ? data.alarms.map(parseAlarm).filter((a): a is Alarm => a !== null) : [];
    const snoozes = Array.isArray(data.snoozes)
      ? (data.snoozes as Snooze[]).filter(
          (s) => s && typeof s.alarmId === "string" && isInt(s.at) && isInt(s.count) && alarms.some((a) => a.id === s.alarmId),
        )
      : [];
    return { alarms, snoozes, seeded: data.seeded === true };
  } catch {
    return null;
  }
}

export function serialize(saved: Saved): string {
  return JSON.stringify(saved);
}

/** Load from localStorage. A first run (or unreadable storage) gets the morning alarm. */
export function load(storage: Pick<Storage, "getItem"> | null): Saved {
  let parsed: Saved | null = null;
  try {
    parsed = parseSaved(storage?.getItem(STORAGE_KEY) ?? null);
  } catch {
    parsed = null;
  }
  if (parsed && parsed.seeded) return parsed;
  return { alarms: [...(parsed?.alarms ?? []), morningAlarm()], snoozes: parsed?.snoozes ?? [], seeded: true };
}

export function save(storage: Pick<Storage, "setItem"> | null, saved: Saved): void {
  try {
    storage?.setItem(STORAGE_KEY, serialize(saved));
  } catch {
    // Private mode or quota: the app still works for this visit.
  }
}
