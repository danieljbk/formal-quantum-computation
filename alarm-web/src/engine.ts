import type { Alarm, WakeRecord } from './types';
import { isDue, previousOccurrenceAtOrBefore } from './schedule';

/** How long the wake-up check waits for "I'm awake" before the baby starts crying again. */
export const WAKE_CHECK_RESPONSE_MS = 60_000;

export type RingPhase =
  | { kind: 'idle' }
  | { kind: 'ringing'; alarmId: string; scheduledAt: number; startedAt: number; snoozeCount: number; recheck: boolean }
  | { kind: 'snoozed'; alarmId: string; scheduledAt: number; until: number; snoozeCount: number }
  | { kind: 'awaitingCheck'; alarmId: string; scheduledAt: number; checkAt: number; snoozeCount: number }
  | { kind: 'checking'; alarmId: string; scheduledAt: number; deadline: number; snoozeCount: number };

export const IDLE: RingPhase = { kind: 'idle' };

export interface TickResult {
  phase: RingPhase;
  /** Alarms whose `lastFiredAt` should be set to `now` (and one-shots disabled). */
  fired: string[];
}

/**
 * Advances the ring state machine to `now`. Starts a ring if an alarm is due, wakes a
 * snooze, opens the wake-up check, or re-rings if the check went unanswered.
 */
export function tick(phase: RingPhase, alarms: Alarm[], now: number): TickResult {
  switch (phase.kind) {
    case 'ringing':
      return { phase, fired: [] };
    case 'snoozed':
      if (now >= phase.until) {
        return {
          phase: { kind: 'ringing', alarmId: phase.alarmId, scheduledAt: phase.scheduledAt, startedAt: now, snoozeCount: phase.snoozeCount, recheck: false },
          fired: [],
        };
      }
      return { phase, fired: [] };
    case 'awaitingCheck':
      if (now >= phase.checkAt) {
        return {
          phase: { kind: 'checking', alarmId: phase.alarmId, scheduledAt: phase.scheduledAt, deadline: now + WAKE_CHECK_RESPONSE_MS, snoozeCount: phase.snoozeCount },
          fired: [],
        };
      }
      break;
    case 'checking':
      if (now >= phase.deadline) {
        return {
          phase: { kind: 'ringing', alarmId: phase.alarmId, scheduledAt: phase.scheduledAt, startedAt: now, snoozeCount: phase.snoozeCount, recheck: true },
          fired: [],
        };
      }
      return { phase, fired: [] };
    case 'idle':
      break;
  }
  // Idle or awaiting a check: a newly due alarm takes over.
  const due = alarms.filter((a) => isDue(a, now));
  if (due.length === 0) return { phase, fired: [] };
  const first = due[0];
  const scheduledAt = previousOccurrenceAtOrBefore(first, now) ?? now;
  return {
    phase: { kind: 'ringing', alarmId: first.id, scheduledAt, startedAt: now, snoozeCount: 0, recheck: false },
    fired: due.map((a) => a.id),
  };
}

export function canSnooze(phase: RingPhase, alarm: Alarm | undefined): boolean {
  if (phase.kind !== 'ringing' || !alarm || !alarm.snooze.enabled || phase.recheck) return false;
  return alarm.snooze.maxCount === 0 || phase.snoozeCount < alarm.snooze.maxCount;
}

export function snooze(phase: RingPhase, alarm: Alarm | undefined, now: number): RingPhase {
  if (phase.kind !== 'ringing' || !alarm || !canSnooze(phase, alarm)) return phase;
  return {
    kind: 'snoozed',
    alarmId: phase.alarmId,
    scheduledAt: phase.scheduledAt,
    until: now + alarm.snooze.minutes * 60_000,
    snoozeCount: phase.snoozeCount + 1,
  };
}

export interface DismissResult {
  phase: RingPhase;
  record: WakeRecord | null;
}

/** Stops the crying (after the mission, if any). Arms the wake-up check when enabled. */
export function dismiss(phase: RingPhase, alarm: Alarm | undefined, now: number): DismissResult {
  if (phase.kind !== 'ringing' && phase.kind !== 'snoozed') return { phase, record: null };
  const record: WakeRecord | null =
    alarm && !(phase.kind === 'ringing' && phase.recheck)
      ? {
          alarmId: phase.alarmId,
          label: alarm.label,
          scheduledAt: phase.scheduledAt,
          dismissedAt: now,
          snoozeCount: phase.snoozeCount,
          mission: alarm.mission.kind,
        }
      : null;
  const recheck = phase.kind === 'ringing' && phase.recheck;
  if (alarm?.wakeUpCheck.enabled && !recheck) {
    return {
      phase: {
        kind: 'awaitingCheck',
        alarmId: phase.alarmId,
        scheduledAt: phase.scheduledAt,
        checkAt: now + alarm.wakeUpCheck.afterMinutes * 60_000,
        snoozeCount: phase.snoozeCount,
      },
      record,
    };
  }
  return { phase: IDLE, record };
}

/** "I'm awake" during a wake-up check. */
export function confirmAwake(phase: RingPhase): RingPhase {
  return phase.kind === 'checking' || phase.kind === 'awaitingCheck' ? IDLE : phase;
}

/** Applies the bookkeeping for alarms that just fired: mark them and retire one-shots. */
export function markFired(alarms: Alarm[], fired: string[], now: number): Alarm[] {
  if (fired.length === 0) return alarms;
  const set = new Set(fired);
  return alarms.map((a) => {
    if (!set.has(a.id)) return a;
    const once = a.repeatDays.length === 0;
    return { ...a, lastFiredAt: now, enabled: once ? false : a.enabled, oneShotAt: once ? undefined : a.oneShotAt };
  });
}

/** Average minutes between scheduled time and dismissal, and on-time streak. */
export function wakeStats(history: WakeRecord[]): { count: number; avgDelayMin: number; snoozes: number; streak: number } {
  if (history.length === 0) return { count: 0, avgDelayMin: 0, snoozes: 0, streak: 0 };
  const delays = history.map((h) => Math.max(0, h.dismissedAt - h.scheduledAt) / 60_000);
  let streak = 0;
  for (let i = history.length - 1; i >= 0 && history[i].snoozeCount === 0; i--) streak++;
  return {
    count: history.length,
    avgDelayMin: Math.round((delays.reduce((s, d) => s + d, 0) / delays.length) * 10) / 10,
    snoozes: history.reduce((s, h) => s + h.snoozeCount, 0),
    streak,
  };
}
