/** 0 = Sunday … 6 = Saturday, matching Date.prototype.getDay(). */
export type Weekday = 0 | 1 | 2 | 3 | 4 | 5 | 6;

export type SoundId = "newborn" | "hungry" | "fussy" | "kunjappi";

/** A specific baby, or a different baby picked at random each time the alarm rings. */
export type VoiceChoice = SoundId | "shuffle";

export type Mission =
  | { kind: "none" }
  | { kind: "math"; difficulty: 1 | 2 | 3; rounds: number }
  | { kind: "typing"; rounds: number }
  | { kind: "rock"; rocks: number };

export interface SnoozeSettings {
  enabled: boolean;
  minutes: number;
  /** How many times the alarm can be snoozed before snooze is refused. */
  maxCount: number;
}

export interface Alarm {
  id: string;
  hour: number;
  minute: number;
  label: string;
  enabled: boolean;
  /** Days the alarm repeats on. Empty means it rings once, then switches off. */
  repeat: Weekday[];
  voice: VoiceChoice;
  /** Peak volume, 0..1. */
  volume: number;
  /** Seconds to fade from quiet to peak volume. 0 rings at full volume at once. */
  rampSeconds: number;
  vibrate: boolean;
  snooze: SnoozeSettings;
  mission: Mission;
  /** Absolute time for a one-off quick alarm ("nap"); overrides hour/minute. */
  fireAt?: number;
  /** Skip every occurrence before this time ("skip next"). */
  skipUntil?: number;
}

/** A pending re-ring after the user pressed snooze. */
export interface Snooze {
  alarmId: string;
  at: number;
  count: number;
}

/** An alarm that is currently crying. */
export interface Ringing {
  alarmId: string;
  firedAt: number;
  /** How many times this ring has already been snoozed. */
  snoozeCount: number;
  /** The concrete baby chosen for this ring (resolves "shuffle"). */
  soundId: SoundId;
}
