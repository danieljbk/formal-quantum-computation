import { dueInWindow, nextOccurrence } from "./schedule";
import { resolveVoice } from "./sounds";
import type { Alarm, Ringing, Snooze } from "./types";

/** Everything the alarm clock needs to decide what rings and when. */
export interface ClockState {
  alarms: Alarm[];
  snoozes: Snooze[];
  ringing: Ringing | null;
  /** Last time the scheduler looked for due alarms. */
  lastCheck: number;
}

function isOneOff(a: Alarm): boolean {
  return a.fireAt !== undefined || a.repeat.length === 0;
}

/**
 * Advance the clock to `now`: anything that came due since lastCheck starts
 * ringing. One-off alarms switch themselves off once they fire. If something is
 * already ringing it keeps ringing (a newly due alarm doesn't interrupt it).
 */
export function tick(state: ClockState, now: number, rng: () => number = Math.random): ClockState {
  if (now <= state.lastCheck) return state;
  const due = dueInWindow(state.alarms, state.snoozes, state.lastCheck, now);
  if (due.length === 0) {
    return { ...state, lastCheck: now };
  }
  const dueIds = new Set(due.map((d) => d.alarmId));
  const alarms = state.alarms.map((a) => {
    if (!dueIds.has(a.id)) return a;
    const next: Alarm = { ...a, skipUntil: undefined };
    if (isOneOff(a)) next.enabled = false;
    return next;
  });
  const snoozes = state.snoozes.filter((s) => !(s.at > state.lastCheck && s.at <= now));

  let ringing = state.ringing;
  if (!ringing) {
    const latest = due[due.length - 1];
    const alarm = state.alarms.find((a) => a.id === latest.alarmId);
    if (alarm) {
      ringing = {
        alarmId: alarm.id,
        firedAt: latest.at,
        snoozeCount: latest.snoozeCount,
        soundId: resolveVoice(alarm.voice, rng),
      };
    }
  }
  return { alarms, snoozes, ringing, lastCheck: now };
}

export function canSnooze(state: ClockState): boolean {
  const r = state.ringing;
  if (!r) return false;
  const alarm = state.alarms.find((a) => a.id === r.alarmId);
  if (!alarm) return false;
  return alarm.snooze.enabled && r.snoozeCount < alarm.snooze.maxCount;
}

export function snoozesLeft(state: ClockState): number {
  const r = state.ringing;
  const alarm = r && state.alarms.find((a) => a.id === r.alarmId);
  if (!r || !alarm || !alarm.snooze.enabled) return 0;
  return Math.max(0, alarm.snooze.maxCount - r.snoozeCount);
}

/** Stop crying for now; cry again after the alarm's snooze interval. */
export function snooze(state: ClockState, now: number): ClockState {
  if (!canSnooze(state)) return state;
  const r = state.ringing!;
  const alarm = state.alarms.find((a) => a.id === r.alarmId)!;
  const entry: Snooze = { alarmId: r.alarmId, at: now + alarm.snooze.minutes * 60_000, count: r.snoozeCount + 1 };
  return {
    ...state,
    ringing: null,
    snoozes: [...state.snoozes.filter((s) => s.alarmId !== r.alarmId), entry],
    lastCheck: Math.max(state.lastCheck, now),
  };
}

/** The mission is done (or there was none): stop ringing for good. */
export function dismiss(state: ClockState, now: number): ClockState {
  if (!state.ringing) return state;
  const id = state.ringing.alarmId;
  return {
    ...state,
    ringing: null,
    snoozes: state.snoozes.filter((s) => s.alarmId !== id),
    lastCheck: Math.max(state.lastCheck, now),
  };
}

/** Skip just the next occurrence of a repeating alarm. */
export function skipNext(state: ClockState, alarmId: string, now: number): ClockState {
  return {
    ...state,
    alarms: state.alarms.map((a) => {
      if (a.id !== alarmId) return a;
      const next = nextOccurrence({ ...a, skipUntil: undefined }, now);
      return next === null ? a : { ...a, skipUntil: next + 1 };
    }),
  };
}

export function upsertAlarm(state: ClockState, alarm: Alarm): ClockState {
  const exists = state.alarms.some((a) => a.id === alarm.id);
  return {
    ...state,
    alarms: exists ? state.alarms.map((a) => (a.id === alarm.id ? alarm : a)) : [...state.alarms, alarm],
    // Editing an alarm cancels its pending snooze.
    snoozes: state.snoozes.filter((s) => s.alarmId !== alarm.id),
  };
}

export function removeAlarm(state: ClockState, alarmId: string): ClockState {
  return {
    ...state,
    alarms: state.alarms.filter((a) => a.id !== alarmId),
    snoozes: state.snoozes.filter((s) => s.alarmId !== alarmId),
    ringing: state.ringing?.alarmId === alarmId ? null : state.ringing,
  };
}

export function setEnabled(state: ClockState, alarmId: string, enabled: boolean): ClockState {
  return {
    ...state,
    alarms: state.alarms.map((a) => (a.id === alarmId ? { ...a, enabled, skipUntil: undefined } : a)),
    snoozes: enabled ? state.snoozes : state.snoozes.filter((s) => s.alarmId !== alarmId),
  };
}

/** Start ringing an alarm right now, for "test this alarm". */
export function ringNow(state: ClockState, alarmId: string, now: number, rng: () => number = Math.random): ClockState {
  const alarm = state.alarms.find((a) => a.id === alarmId);
  if (!alarm) return state;
  return {
    ...state,
    ringing: { alarmId, firedAt: now, snoozeCount: 0, soundId: resolveVoice(alarm.voice, rng) },
  };
}
