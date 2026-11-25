import type { Alarm, PersistedState, Settings, WakeRecord, Weekday } from './types';
import { DEFAULT_SOUND, isSoundId } from './sounds';
import { DEFAULT_MISSION } from './missions';

export const STORAGE_KEY = 'wail-alarm/v1';
const MAX_HISTORY = 60;

export interface KeyValueStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
}

export const DEFAULT_SETTINGS: Settings = { use24h: false, defaultSound: DEFAULT_SOUND };

let idCounter = 0;
export function newId(now = Date.now()): string {
  idCounter = (idCounter + 1) % 1_000_000;
  return `${now.toString(36)}-${idCounter.toString(36)}-${Math.random().toString(36).slice(2, 7)}`;
}

export function createAlarm(partial: Partial<Alarm> = {}, now = Date.now()): Alarm {
  return {
    id: newId(now),
    hour: 7,
    minute: 0,
    label: 'Morning',
    enabled: true,
    repeatDays: [],
    sound: DEFAULT_SOUND,
    volume: 0.9,
    fadeInSeconds: 20,
    vibrate: true,
    mission: { ...DEFAULT_MISSION },
    snooze: { enabled: true, minutes: 5, maxCount: 3 },
    wakeUpCheck: { enabled: false, afterMinutes: 5 },
    createdAt: now,
    ...partial,
  };
}

/** A first-run state: a weekday morning alarm so the app is useful immediately. */
export function initialState(now = Date.now()): PersistedState {
  return {
    version: 1,
    alarms: [
      createAlarm({ label: 'Morning', hour: 7, minute: 0, repeatDays: [1, 2, 3, 4, 5], enabled: false }, now),
    ],
    history: [],
    settings: { ...DEFAULT_SETTINGS },
  };
}

function clampInt(v: unknown, min: number, max: number, fallback: number): number {
  return typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, Math.round(v))) : fallback;
}

function clampNum(v: unknown, min: number, max: number, fallback: number): number {
  return typeof v === 'number' && Number.isFinite(v) ? Math.min(max, Math.max(min, v)) : fallback;
}

/** Validates one stored alarm, repairing fields where possible; returns null if unusable. */
export function sanitizeAlarm(raw: unknown, now = Date.now()): Alarm | null {
  if (!raw || typeof raw !== 'object') return null;
  const r = raw as Record<string, unknown>;
  if (typeof r.id !== 'string') return null;
  const base = createAlarm({}, now);
  const mission = (r.mission ?? {}) as Record<string, unknown>;
  const snooze = (r.snooze ?? {}) as Record<string, unknown>;
  const check = (r.wakeUpCheck ?? {}) as Record<string, unknown>;
  const kinds = ['none', 'math', 'shake', 'typing', 'memory', 'tap'];
  const diffs = ['easy', 'medium', 'hard'];
  return {
    id: r.id,
    hour: clampInt(r.hour, 0, 23, base.hour),
    minute: clampInt(r.minute, 0, 59, base.minute),
    label: typeof r.label === 'string' ? r.label.slice(0, 40) : base.label,
    enabled: typeof r.enabled === 'boolean' ? r.enabled : false,
    repeatDays: Array.isArray(r.repeatDays)
      ? [...new Set(r.repeatDays.filter((d): d is Weekday => Number.isInteger(d) && d >= 0 && d <= 6))].sort()
      : [],
    sound: isSoundId(r.sound) ? r.sound : base.sound,
    volume: clampNum(r.volume, 0.05, 1, base.volume),
    fadeInSeconds: clampInt(r.fadeInSeconds, 0, 120, base.fadeInSeconds),
    vibrate: typeof r.vibrate === 'boolean' ? r.vibrate : base.vibrate,
    mission: {
      kind: kinds.includes(mission.kind as string) ? (mission.kind as Alarm['mission']['kind']) : base.mission.kind,
      difficulty: diffs.includes(mission.difficulty as string)
        ? (mission.difficulty as Alarm['mission']['difficulty'])
        : base.mission.difficulty,
      rounds: clampInt(mission.rounds, 1, 5, base.mission.rounds),
    },
    snooze: {
      enabled: typeof snooze.enabled === 'boolean' ? snooze.enabled : base.snooze.enabled,
      minutes: clampInt(snooze.minutes, 1, 30, base.snooze.minutes),
      maxCount: clampInt(snooze.maxCount, 0, 10, base.snooze.maxCount),
    },
    wakeUpCheck: {
      enabled: typeof check.enabled === 'boolean' ? check.enabled : base.wakeUpCheck.enabled,
      afterMinutes: clampInt(check.afterMinutes, 1, 30, base.wakeUpCheck.afterMinutes),
    },
    oneShotAt: typeof r.oneShotAt === 'number' ? r.oneShotAt : undefined,
    lastFiredAt: typeof r.lastFiredAt === 'number' ? r.lastFiredAt : undefined,
    createdAt: typeof r.createdAt === 'number' ? r.createdAt : now,
  };
}

export function loadState(store: KeyValueStore | undefined, now = Date.now()): PersistedState {
  let raw: string | null = null;
  try {
    raw = store?.getItem(STORAGE_KEY) ?? null;
  } catch {
    raw = null;
  }
  if (!raw) return initialState(now);
  try {
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    if (parsed.version !== 1) return initialState(now);
    const alarms = Array.isArray(parsed.alarms)
      ? parsed.alarms.map((a) => sanitizeAlarm(a, now)).filter((a): a is Alarm => a !== null)
      : [];
    const history = Array.isArray(parsed.history)
      ? (parsed.history as WakeRecord[]).filter(
          (h) => h && typeof h.dismissedAt === 'number' && typeof h.scheduledAt === 'number',
        )
      : [];
    const s = (parsed.settings ?? {}) as Partial<Settings>;
    return {
      version: 1,
      alarms,
      history: history.slice(-MAX_HISTORY),
      settings: {
        use24h: typeof s.use24h === 'boolean' ? s.use24h : DEFAULT_SETTINGS.use24h,
        defaultSound: isSoundId(s.defaultSound) ? s.defaultSound : DEFAULT_SETTINGS.defaultSound,
      },
    };
  } catch {
    return initialState(now);
  }
}

export function saveState(store: KeyValueStore | undefined, state: PersistedState): void {
  try {
    store?.setItem(STORAGE_KEY, JSON.stringify({ ...state, history: state.history.slice(-MAX_HISTORY) }));
  } catch {
    // Private mode or quota: the app keeps working in memory.
  }
}

export function browserStore(): KeyValueStore | undefined {
  try {
    return typeof window !== 'undefined' ? window.localStorage : undefined;
  } catch {
    return undefined;
  }
}
