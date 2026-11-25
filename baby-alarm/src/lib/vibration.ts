import type { VibrationPatternId } from "./types";

/** Vibration API patterns (ms on/off). Each loops while the alarm rings. */
export const VIBRATION_PATTERNS: Record<VibrationPatternId, { name: string; pattern: number[] }> = {
  heartbeat: { name: "Heartbeat", pattern: [120, 90, 220, 700] },
  lullaby: { name: "Lullaby rock", pattern: [400, 300, 400, 300, 800, 900] },
  siren: { name: "Siren", pattern: [600, 150, 600, 150, 600, 150] },
  off: { name: "Off", pattern: [] },
};

export function patternDuration(id: VibrationPatternId): number {
  return VIBRATION_PATTERNS[id].pattern.reduce((a, b) => a + b, 0);
}

type Vibrate = (pattern: number | number[]) => boolean;

function getVibrate(): Vibrate | null {
  if (typeof navigator === "undefined" || typeof navigator.vibrate !== "function") return null;
  return navigator.vibrate.bind(navigator);
}

export function canVibrate(): boolean {
  return getVibrate() !== null;
}

/**
 * Start looping a vibration pattern. Returns a stop function.
 * On devices without the Vibration API (e.g. iOS Safari) this is a no-op and
 * the UI shows a visual pulse instead.
 */
export function startVibration(id: VibrationPatternId, vibrate: Vibrate | null = getVibrate()): () => void {
  const { pattern } = VIBRATION_PATTERNS[id];
  if (!vibrate || pattern.length === 0) return () => {};
  vibrate(pattern);
  const timer = setInterval(() => vibrate(pattern), patternDuration(id));
  return () => {
    clearInterval(timer);
    vibrate(0);
  };
}
