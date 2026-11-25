import { describe, expect, it, vi } from "vitest";
import { VIBRATION_PATTERNS, patternDuration, startVibration } from "../src/lib/vibration";
import { rampVolume } from "../src/lib/audio";

describe("vibration", () => {
  it("loops the pattern and stops cleanly", () => {
    vi.useFakeTimers();
    const vibrate = vi.fn(() => true);
    const stop = startVibration("heartbeat", vibrate);
    expect(vibrate).toHaveBeenCalledWith(VIBRATION_PATTERNS.heartbeat.pattern);
    vi.advanceTimersByTime(patternDuration("heartbeat") * 3);
    expect(vibrate).toHaveBeenCalledTimes(4);
    stop();
    expect(vibrate).toHaveBeenLastCalledWith(0);
    vi.useRealTimers();
  });
  it("is a no-op when off or unsupported", () => {
    const vibrate = vi.fn(() => true);
    startVibration("off", vibrate)();
    expect(vibrate).not.toHaveBeenCalled();
    expect(() => startVibration("siren", null)()).not.toThrow();
  });
});

describe("volume ramp", () => {
  it("ramps linearly from 20% to target", () => {
    expect(rampVolume(0, 20, 1)).toBeCloseTo(0.2);
    expect(rampVolume(10, 20, 1)).toBeCloseTo(0.6);
    expect(rampVolume(40, 20, 1)).toBeCloseTo(1);
    expect(rampVolume(5, 0, 0.7)).toBe(0.7);
  });
});
