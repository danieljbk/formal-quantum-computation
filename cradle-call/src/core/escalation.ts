/**
 * Multi-stage escalation ramp. The cry starts as a quiet whimper and grows
 * through four stages; in the later stages more babies join in (extra voice
 * layers), so ignoring the alarm only makes the nursery louder.
 */
export interface Stage {
  name: string;
  /** Seconds after the alarm starts ringing when this stage begins. */
  startsAt: number;
  fromVolume: number;
  toVolume: number;
  /** Number of simultaneous baby voices. */
  layers: number;
  vibrate: boolean;
}

export const STAGES: readonly Stage[] = [
  { name: 'Whimper', startsAt: 0, fromVolume: 0.15, toVolume: 0.35, layers: 1, vibrate: false },
  { name: 'Fussing', startsAt: 20, fromVolume: 0.35, toVolume: 0.6, layers: 1, vibrate: true },
  { name: 'Crying', startsAt: 45, fromVolume: 0.6, toVolume: 0.85, layers: 2, vibrate: true },
  { name: 'Full nursery', startsAt: 75, fromVolume: 0.85, toVolume: 1, layers: 3, vibrate: true },
];

/** Duration of the final stage's ramp before it holds at its top volume. */
const FINAL_RAMP_SECONDS = 30;

/** While a mission is being solved, the cry is ducked to this fraction. */
export const MISSION_DUCK = 0.2;

export interface EscalationLevel {
  stageIndex: number;
  stage: Stage;
  volume: number;
  layers: number;
  vibrate: boolean;
  /** 0..1 progress through the whole ramp, for UI. */
  progress: number;
}

export function stageIndexAt(elapsedSeconds: number): number {
  let idx = 0;
  for (let i = 0; i < STAGES.length; i++) if (elapsedSeconds >= STAGES[i].startsAt) idx = i;
  return idx;
}

export function escalationAt(elapsedSeconds: number, maxVolume = 1, ducked = false): EscalationLevel {
  const t = Math.max(0, elapsedSeconds);
  const stageIndex = stageIndexAt(t);
  const stage = STAGES[stageIndex];
  const next = STAGES[stageIndex + 1];
  const span = next ? next.startsAt - stage.startsAt : FINAL_RAMP_SECONDS;
  const within = Math.min(1, (t - stage.startsAt) / span);
  const raw = stage.fromVolume + (stage.toVolume - stage.fromVolume) * within;
  const ceiling = Math.min(1, Math.max(0.1, maxVolume));
  const volume = raw * ceiling * (ducked ? MISSION_DUCK : 1);
  const end = STAGES[STAGES.length - 1].startsAt + FINAL_RAMP_SECONDS;
  return {
    stageIndex,
    stage,
    volume,
    layers: ducked ? 1 : stage.layers,
    vibrate: !ducked && stage.vibrate,
    progress: Math.min(1, t / end),
  };
}

/** Which voices play for a given number of layers: the chosen one first, then others join. */
export function layerVoices(primaryId: string, allIds: readonly string[], layers: number): string[] {
  const others = allIds.filter((id) => id !== primaryId);
  return [primaryId, ...others].slice(0, Math.max(1, layers));
}
