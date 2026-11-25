import { defaultMission } from './missions';
import { dueOccurrence } from './schedule';
import type { Alarm, AppState, MissionConfig, RingReason, Ringing, Screen, Settings, WakeRecord } from './types';

export const STORAGE_KEY = 'cradle-call/v1';
export const WAKE_CHECK_RESPONSE_SECONDS = 60;
export const MAX_HISTORY = 200;

export const DEFAULT_SETTINGS: Settings = {
  use24h: false,
  defaultVoiceId: 'newborn',
  missionIdleSeconds: 25,
};

let idCounter = 0;
export function newId(now: number): string {
  idCounter = (idCounter + 1) % 1_000_000;
  return `a${now.toString(36)}${idCounter.toString(36)}`;
}

export function makeAlarm(now: number, partial: Partial<Alarm> = {}, voiceId = DEFAULT_SETTINGS.defaultVoiceId): Alarm {
  return {
    id: newId(now),
    hour: 7,
    minute: 0,
    label: 'Wake up',
    enabled: true,
    repeat: [1, 2, 3, 4, 5],
    voiceId,
    missions: [defaultMission('math')],
    snoozeLimit: 2,
    snoozeMinutes: 5,
    wakeCheck: true,
    wakeCheckMinutes: 5,
    vibrate: true,
    maxVolume: 1,
    createdAt: now,
    ...partial,
  };
}

export function initialState(): AppState {
  return {
    alarms: [],
    history: [],
    ringing: null,
    snoozed: [],
    wakeChecks: [],
    firedKeys: [],
    settings: DEFAULT_SETTINGS,
    screen: 'alarms',
    editingId: null,
    briefing: null,
  };
}

/** Every alarm must carry at least one mission gate: there is no button-press dismissal. */
export function normalizeAlarm(alarm: Alarm): Alarm {
  const missions: MissionConfig[] = alarm.missions.length > 0 ? alarm.missions.slice(0, 5) : [defaultMission('math')];
  return {
    ...alarm,
    hour: Math.min(23, Math.max(0, Math.floor(alarm.hour))),
    minute: Math.min(59, Math.max(0, Math.floor(alarm.minute))),
    repeat: [...new Set(alarm.repeat)].filter((d) => d >= 0 && d <= 6).sort(),
    missions: missions.map((m) => ({ ...m, rounds: Math.min(10, Math.max(1, Math.floor(m.rounds))) })),
    snoozeLimit: Math.min(10, Math.max(0, Math.floor(alarm.snoozeLimit))),
    snoozeMinutes: Math.min(30, Math.max(1, Math.floor(alarm.snoozeMinutes))),
    wakeCheckMinutes: Math.min(30, Math.max(1, Math.floor(alarm.wakeCheckMinutes))),
    maxVolume: Math.min(1, Math.max(0.1, alarm.maxVolume)),
  };
}

export type Action =
  | { type: 'TICK'; now: number }
  | { type: 'SAVE_ALARM'; alarm: Alarm }
  | { type: 'DELETE_ALARM'; id: string }
  | { type: 'TOGGLE_ALARM'; id: string }
  | { type: 'QUICK_ALARM'; now: number; minutes: number }
  | { type: 'TEST_ALARM'; id: string; now: number }
  | { type: 'START_MISSIONS'; now: number }
  | { type: 'MISSION_ACTIVITY'; now: number }
  | { type: 'MISSION_COMPLETE'; now: number; index: number }
  | { type: 'SNOOZE'; now: number }
  | { type: 'CONFIRM_AWAKE'; now: number }
  | { type: 'NAVIGATE'; screen: Screen; editingId?: string | null }
  | { type: 'UPDATE_SETTINGS'; settings: Partial<Settings> }
  | { type: 'CLEAR_HISTORY' };

function ring(state: AppState, alarmId: string, reason: RingReason, now: number, carry?: { firstFiredAt: number; snoozesUsed: number }): AppState {
  const ringing: Ringing = {
    alarmId,
    reason,
    startedAt: now,
    firstFiredAt: carry?.firstFiredAt ?? now,
    snoozesUsed: carry?.snoozesUsed ?? 0,
    phase: 'ringing',
    missionIndex: 0,
    lastActivityAt: now,
    seed: (now ^ 0x5bd1e995) >>> 0,
  };
  return { ...state, ringing, briefing: null };
}

function tick(state: AppState, now: number): AppState {
  let s = state;

  // A mission left idle hands control back to the escalating cry.
  if (s.ringing && s.ringing.phase === 'mission' && now - s.ringing.lastActivityAt > s.settings.missionIdleSeconds * 1000) {
    s = { ...s, ringing: { ...s.ringing, phase: 'ringing' } };
  }

  // Wake-up checks that went unanswered ring the alarm again (missions required again).
  for (const wc of s.wakeChecks) {
    if (wc.deadline !== null && now >= wc.deadline && !s.ringing) {
      s = { ...s, wakeChecks: s.wakeChecks.filter((w) => w !== wc) };
      return ring(s, wc.alarmId, 'wakeCheck', now);
    }
  }
  // Wake-up checks that came due start their response window.
  if (!s.ringing) {
    const due = s.wakeChecks.find((w) => w.deadline === null && now >= w.due);
    if (due) {
      s = {
        ...s,
        wakeChecks: s.wakeChecks.map((w) => (w === due ? { ...w, deadline: now + WAKE_CHECK_RESPONSE_SECONDS * 1000 } : w)),
      };
    }
  }

  if (s.ringing) return s;

  // Snoozes that ran out ring again.
  const snoozeDue = s.snoozed.find((z) => now >= z.until);
  if (snoozeDue) {
    s = { ...s, snoozed: s.snoozed.filter((z) => z !== snoozeDue) };
    return ring(s, snoozeDue.alarmId, snoozeDue.reason === 'test' ? 'test' : 'snooze', now, snoozeDue);
  }

  // Scheduled alarms.
  const date = new Date(now);
  for (const alarm of s.alarms) {
    const key = dueOccurrence(alarm, date, s.firedKeys);
    if (!key) continue;
    const firedKeys = [...s.firedKeys, key].slice(-100);
    const alarms = alarm.repeat.length === 0 ? s.alarms.map((a) => (a.id === alarm.id ? { ...a, enabled: false } : a)) : s.alarms;
    return ring({ ...s, firedKeys, alarms }, alarm.id, 'alarm', now);
  }
  return s;
}

function dismiss(state: AppState, now: number): AppState {
  const r = state.ringing;
  if (!r) return state;
  const alarm = state.alarms.find((a) => a.id === r.alarmId);
  const record: WakeRecord = {
    alarmId: r.alarmId,
    label: alarm?.label ?? 'Alarm',
    voiceId: alarm?.voiceId ?? state.settings.defaultVoiceId,
    firedAt: r.firstFiredAt,
    dismissedAt: now,
    snoozes: r.snoozesUsed,
    missions: alarm?.missions.length ?? 0,
    reason: r.reason,
  };
  const wakeChecks =
    alarm && alarm.wakeCheck && r.reason !== 'test' && r.reason !== 'wakeCheck'
      ? [...state.wakeChecks.filter((w) => w.alarmId !== alarm.id), { alarmId: alarm.id, due: now + alarm.wakeCheckMinutes * 60_000, deadline: null }]
      : state.wakeChecks;
  return {
    ...state,
    ringing: null,
    wakeChecks,
    history: [record, ...state.history].slice(0, MAX_HISTORY),
    briefing: record,
    screen: 'briefing',
  };
}

export function reducer(state: AppState, action: Action): AppState {
  const ringingId = state.ringing?.alarmId;
  switch (action.type) {
    case 'TICK':
      return tick(state, action.now);

    case 'SAVE_ALARM': {
      const alarm = normalizeAlarm(action.alarm);
      const exists = state.alarms.some((a) => a.id === alarm.id);
      const alarms = exists ? state.alarms.map((a) => (a.id === alarm.id ? alarm : a)) : [...state.alarms, alarm];
      return { ...state, alarms, screen: 'alarms', editingId: null };
    }

    case 'DELETE_ALARM':
      // The alarm that is ringing (or snoozed) cannot be deleted to silence it.
      if (action.id === ringingId || state.snoozed.some((z) => z.alarmId === action.id)) return state;
      return {
        ...state,
        alarms: state.alarms.filter((a) => a.id !== action.id),
        wakeChecks: state.wakeChecks.filter((w) => w.alarmId !== action.id),
        screen: 'alarms',
        editingId: null,
      };

    case 'TOGGLE_ALARM':
      if (action.id === ringingId || state.snoozed.some((z) => z.alarmId === action.id)) return state;
      return { ...state, alarms: state.alarms.map((a) => (a.id === action.id ? { ...a, enabled: !a.enabled } : a)) };

    case 'QUICK_ALARM': {
      const at = new Date(action.now + action.minutes * 60_000);
      const alarm = makeAlarm(
        action.now,
        {
          hour: at.getHours(),
          minute: at.getMinutes(),
          label: `Nap · ${action.minutes} min`,
          repeat: [],
          wakeCheck: false,
          snoozeLimit: 1,
        },
        state.settings.defaultVoiceId,
      );
      return { ...state, alarms: [...state.alarms, alarm] };
    }

    case 'TEST_ALARM':
      if (state.ringing || !state.alarms.some((a) => a.id === action.id)) return state;
      return ring(state, action.id, 'test', action.now);

    case 'START_MISSIONS':
      if (!state.ringing) return state;
      return { ...state, ringing: { ...state.ringing, phase: 'mission', lastActivityAt: action.now } };

    case 'MISSION_ACTIVITY':
      if (!state.ringing || state.ringing.phase !== 'mission') return state;
      return { ...state, ringing: { ...state.ringing, lastActivityAt: action.now } };

    case 'MISSION_COMPLETE': {
      const r = state.ringing;
      if (!r || r.phase !== 'mission' || action.index !== r.missionIndex) return state;
      const alarm = state.alarms.find((a) => a.id === r.alarmId);
      const total = alarm ? alarm.missions.length : 1;
      const nextIndex = r.missionIndex + 1;
      if (nextIndex < total) return { ...state, ringing: { ...r, missionIndex: nextIndex, lastActivityAt: action.now } };
      return dismiss(state, action.now);
    }

    case 'SNOOZE': {
      const r = state.ringing;
      if (!r) return state;
      const alarm = state.alarms.find((a) => a.id === r.alarmId);
      if (!alarm || r.snoozesUsed >= alarm.snoozeLimit || r.reason === 'wakeCheck') return state;
      return {
        ...state,
        ringing: null,
        snoozed: [
          ...state.snoozed,
          { alarmId: r.alarmId, until: action.now + alarm.snoozeMinutes * 60_000, firstFiredAt: r.firstFiredAt, snoozesUsed: r.snoozesUsed + 1, reason: r.reason },
        ],
      };
    }

    case 'CONFIRM_AWAKE':
      return { ...state, wakeChecks: state.wakeChecks.filter((w) => !(w.deadline !== null && action.now < w.deadline)) };

    case 'NAVIGATE':
      return { ...state, screen: action.screen, editingId: action.editingId ?? null };

    case 'UPDATE_SETTINGS':
      return { ...state, settings: { ...state.settings, ...action.settings } };

    case 'CLEAR_HISTORY':
      return { ...state, history: [] };
  }
}

/** True iff the current ringing episode may be snoozed. */
export function canSnooze(state: AppState): boolean {
  const r = state.ringing;
  if (!r || r.reason === 'wakeCheck') return false;
  const alarm = state.alarms.find((a) => a.id === r.alarmId);
  return !!alarm && r.snoozesUsed < alarm.snoozeLimit;
}

export function activeWakeCheck(state: AppState) {
  return state.wakeChecks.find((w) => w.deadline !== null) ?? null;
}

export function loadState(storage: Pick<Storage, 'getItem'> | undefined): AppState {
  const base = initialState();
  try {
    const raw = storage?.getItem(STORAGE_KEY);
    if (!raw) return base;
    const saved = JSON.parse(raw) as Partial<AppState>;
    return {
      ...base,
      ...saved,
      alarms: (saved.alarms ?? []).map(normalizeAlarm),
      settings: { ...DEFAULT_SETTINGS, ...(saved.settings ?? {}) },
      // A ringing alarm survives a reload: refreshing the page does not silence it.
      screen: 'alarms',
      editingId: null,
    };
  } catch {
    return base;
  }
}

export function saveState(storage: Pick<Storage, 'setItem'> | undefined, state: AppState): void {
  try {
    const { screen: _s, editingId: _e, ...rest } = state;
    void _s;
    void _e;
    storage?.setItem(STORAGE_KEY, JSON.stringify(rest));
  } catch {
    /* storage unavailable (private mode) — the app still works for this session */
  }
}

export function wakeStats(history: readonly WakeRecord[]) {
  const real = history.filter((h) => h.reason !== 'test');
  if (real.length === 0) return { count: 0, avgSecondsToWake: 0, snoozeFree: 0, streak: 0 };
  const avg = real.reduce((sum, h) => sum + (h.dismissedAt - h.firedAt) / 1000, 0) / real.length;
  const snoozeFree = real.filter((h) => h.snoozes === 0).length;
  let streak = 0;
  for (const h of real) {
    if (h.snoozes === 0) streak++;
    else break;
  }
  return { count: real.length, avgSecondsToWake: Math.round(avg), snoozeFree, streak };
}
