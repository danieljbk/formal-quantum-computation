export type Weekday = 0 | 1 | 2 | 3 | 4 | 5 | 6;

export type ChallengeKind = "math" | "shake" | "typing" | "memory" | "rock" | "sequence";

export type Difficulty = "easy" | "medium" | "hard";

export type VibrationPatternId = "heartbeat" | "lullaby" | "siren" | "off";

export interface Alarm {
  id: string;
  /** 24h clock, 0-23 */
  hour: number;
  minute: number;
  label: string;
  enabled: boolean;
  /** Empty = one-shot alarm (fires at the next occurrence, then disables). */
  repeat: Weekday[];
  soundId: string;
  challenge: ChallengeKind;
  difficulty: Difficulty;
  vibration: VibrationPatternId;
  snoozeMinutes: number;
  maxSnoozes: number;
}

export interface Settings {
  /** 0..1 */
  volume: number;
  /** Seconds to ramp volume from 20% to full. 0 = no ramp. */
  rampSeconds: number;
  use24h: boolean;
  defaultSoundId: string;
  defaultChallenge: ChallengeKind;
}

export interface WakeRecord {
  id: string;
  alarmId: string;
  alarmLabel: string;
  /** epoch ms when the alarm started ringing (first ring) */
  firedAt: number;
  /** epoch ms when the challenge was solved */
  dismissedAt: number;
  snoozes: number;
  challenge: ChallengeKind;
  soundId: string;
  /** challenge attempts that failed before success */
  failedAttempts: number;
}

export interface AppState {
  version: 1;
  alarms: Alarm[];
  settings: Settings;
  history: WakeRecord[];
}

export interface ChallengeProps {
  difficulty: Difficulty;
  onSolved: () => void;
  onFailedAttempt: () => void;
  /** injectable RNG for deterministic tests */
  rng?: () => number;
}
