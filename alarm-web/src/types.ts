/** 0 = Sunday … 6 = Saturday, matching `Date.prototype.getDay`. */
export type Weekday = 0 | 1 | 2 | 3 | 4 | 5 | 6;

export type SoundId = 'newborn' | 'wanting' | 'disappointed' | 'kunjappi';

export type MissionKind = 'none' | 'math' | 'shake' | 'typing' | 'memory' | 'tap';

export type Difficulty = 'easy' | 'medium' | 'hard';

export interface MissionConfig {
  kind: MissionKind;
  difficulty: Difficulty;
  /** How many rounds must be completed (math problems, phrases, shakes ×10, …). */
  rounds: number;
}

export interface Alarm {
  id: string;
  /** 0–23 */
  hour: number;
  /** 0–59 */
  minute: number;
  label: string;
  enabled: boolean;
  /** Empty = ring once (next occurrence), otherwise repeat on these weekdays. */
  repeatDays: Weekday[];
  sound: SoundId;
  /** 0–1 target volume. */
  volume: number;
  /** Seconds to ramp from silence to `volume`; 0 = start at full volume. */
  fadeInSeconds: number;
  vibrate: boolean;
  mission: MissionConfig;
  snooze: {
    enabled: boolean;
    minutes: number;
    /** Maximum snoozes per ring; 0 = unlimited. */
    maxCount: number;
  };
  /** Re-checks you're awake N minutes after dismissal; re-rings if you don't answer. */
  wakeUpCheck: {
    enabled: boolean;
    afterMinutes: number;
  };
  /** Timestamp (ms) of the one-off occurrence this alarm is scheduled for, if any. */
  oneShotAt?: number;
  /** Timestamp (ms) of the last time this alarm rang, to avoid double-firing in the same minute. */
  lastFiredAt?: number;
  createdAt: number;
}

export interface WakeRecord {
  alarmId: string;
  label: string;
  scheduledAt: number;
  dismissedAt: number;
  snoozeCount: number;
  mission: MissionKind;
}

export interface Settings {
  /** Use 24-hour clock in the UI. */
  use24h: boolean;
  /** Default sound for new alarms. */
  defaultSound: SoundId;
}

export interface PersistedState {
  version: 1;
  alarms: Alarm[];
  history: WakeRecord[];
  settings: Settings;
}
