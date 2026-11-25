export type Weekday = 0 | 1 | 2 | 3 | 4 | 5 | 6;

export type MissionKind = 'math' | 'typing' | 'memory' | 'rock' | 'sequence' | 'colors';
export type Difficulty = 'easy' | 'normal' | 'hard';

export interface MissionConfig {
  kind: MissionKind;
  difficulty: Difficulty;
  /** How many rounds (problems, phrases, boards...) must be cleared. */
  rounds: number;
}

export interface Alarm {
  id: string;
  hour: number;
  minute: number;
  label: string;
  enabled: boolean;
  /** Empty = one-shot alarm (disables itself after it rings). */
  repeat: Weekday[];
  voiceId: string;
  missions: MissionConfig[];
  /** 0 disables snooze entirely. */
  snoozeLimit: number;
  snoozeMinutes: number;
  wakeCheck: boolean;
  wakeCheckMinutes: number;
  vibrate: boolean;
  /** Ceiling for the escalation ramp, 0.1 – 1. */
  maxVolume: number;
  createdAt: number;
}

export type RingReason = 'alarm' | 'snooze' | 'wakeCheck' | 'test';

export interface Ringing {
  alarmId: string;
  reason: RingReason;
  /** When this ringing episode (re)started; escalation is measured from here. */
  startedAt: number;
  /** When the alarm first went off, across snoozes. */
  firstFiredAt: number;
  snoozesUsed: number;
  phase: 'ringing' | 'mission';
  /** Index into alarm.missions of the mission currently in progress. */
  missionIndex: number;
  /** Last user interaction during a mission (for the idle timeout). */
  lastActivityAt: number;
  /** Seed for deterministic mission generation. */
  seed: number;
}

export interface Snoozed {
  alarmId: string;
  until: number;
  firstFiredAt: number;
  snoozesUsed: number;
  reason: RingReason;
}

export interface WakeCheck {
  alarmId: string;
  /** When the check pops up. */
  due: number;
  /** Once shown: deadline to confirm, otherwise the alarm rings again. */
  deadline: number | null;
}

export interface WakeRecord {
  alarmId: string;
  label: string;
  voiceId: string;
  firedAt: number;
  dismissedAt: number;
  snoozes: number;
  missions: number;
  reason: RingReason;
}

export interface Settings {
  use24h: boolean;
  defaultVoiceId: string;
  /** Seconds of no interaction during a mission before the cry comes back at full force. */
  missionIdleSeconds: number;
}

export type Screen = 'alarms' | 'editor' | 'history' | 'settings' | 'briefing';

export interface AppState {
  alarms: Alarm[];
  history: WakeRecord[];
  ringing: Ringing | null;
  snoozed: Snoozed[];
  wakeChecks: WakeCheck[];
  /** occurrence keys already fired, so one scheduled minute rings once. */
  firedKeys: string[];
  settings: Settings;
  screen: Screen;
  editingId: string | null;
  briefing: WakeRecord | null;
}
