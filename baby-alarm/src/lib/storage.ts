import type { Alarm, AppState, Settings } from "./types";
import { DEFAULT_SOUND_ID } from "../data/sounds";

export const STORAGE_KEY = "cry-awake/state/v1";
const HISTORY_LIMIT = 365;

export const DEFAULT_SETTINGS: Settings = {
  volume: 0.9,
  rampSeconds: 20,
  use24h: false,
  defaultSoundId: DEFAULT_SOUND_ID,
  defaultChallenge: "math",
};

export function makeId(): string {
  return Math.random().toString(36).slice(2, 10) + Date.now().toString(36).slice(-4);
}

export function newAlarm(settings: Settings, partial: Partial<Alarm> = {}): Alarm {
  return {
    id: makeId(),
    hour: 7,
    minute: 0,
    label: "Morning",
    enabled: true,
    repeat: [1, 2, 3, 4, 5],
    soundId: settings.defaultSoundId,
    challenge: settings.defaultChallenge,
    difficulty: "medium",
    vibration: "heartbeat",
    snoozeMinutes: 5,
    maxSnoozes: 2,
    ...partial,
  };
}

export function defaultState(): AppState {
  const settings = { ...DEFAULT_SETTINGS };
  return {
    version: 1,
    settings,
    alarms: [newAlarm(settings, { id: "morning", label: "Morning" })],
    history: [],
  };
}

function isObj(v: unknown): v is Record<string, unknown> {
  return typeof v === "object" && v !== null;
}

/** Parse and sanitise persisted JSON; anything unrecognised falls back to defaults. */
export function parseState(raw: string | null): AppState {
  const base = defaultState();
  if (!raw) return base;
  let data: unknown;
  try {
    data = JSON.parse(raw);
  } catch {
    return base;
  }
  if (!isObj(data) || data.version !== 1) return base;
  const settings: Settings = { ...base.settings, ...(isObj(data.settings) ? (data.settings as Partial<Settings>) : {}) };
  settings.volume = clamp(Number(settings.volume), 0, 1, base.settings.volume);
  settings.rampSeconds = clamp(Number(settings.rampSeconds), 0, 120, base.settings.rampSeconds);
  const alarms = Array.isArray(data.alarms)
    ? (data.alarms as unknown[]).filter(isObj).map((a) => newAlarm(settings, a as Partial<Alarm>))
    : base.alarms;
  const history = Array.isArray(data.history) ? (data.history as AppState["history"]).filter(isObj) : [];
  return { version: 1, settings, alarms, history: history.slice(-HISTORY_LIMIT) };
}

function clamp(v: number, lo: number, hi: number, fallback: number): number {
  if (!Number.isFinite(v)) return fallback;
  return Math.min(hi, Math.max(lo, v));
}

export function loadState(storage: Pick<Storage, "getItem"> | undefined = safeStorage()): AppState {
  try {
    return parseState(storage?.getItem(STORAGE_KEY) ?? null);
  } catch {
    return defaultState();
  }
}

export function saveState(state: AppState, storage: Pick<Storage, "setItem"> | undefined = safeStorage()): boolean {
  try {
    if (!storage) return false;
    storage.setItem(STORAGE_KEY, JSON.stringify({ ...state, history: state.history.slice(-HISTORY_LIMIT) }));
    return true;
  } catch {
    return false;
  }
}

function safeStorage(): Storage | undefined {
  try {
    return typeof window !== "undefined" ? window.localStorage : undefined;
  } catch {
    return undefined;
  }
}
