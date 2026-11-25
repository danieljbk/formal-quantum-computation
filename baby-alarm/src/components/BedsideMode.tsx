import { useEffect } from "react";
import type { Alarm, Settings } from "../lib/types";
import { formatCountdown, formatTime, nextAlarm } from "../lib/scheduler";

type WakeLockSentinelLike = { release: () => Promise<void> };

/** Dim full-screen clock that keeps the screen awake so alarms can ring overnight. */
export function BedsideMode({ alarms, settings, now, onExit }: { alarms: Alarm[]; settings: Settings; now: Date; onExit: () => void }) {
  useEffect(() => {
    let lock: WakeLockSentinelLike | null = null;
    const nav = navigator as Navigator & { wakeLock?: { request: (t: "screen") => Promise<WakeLockSentinelLike> } };
    nav.wakeLock?.request("screen").then((l) => (lock = l)).catch(() => {});
    return () => {
      void lock?.release().catch(() => {});
    };
  }, []);
  const up = nextAlarm(alarms, now);
  return (
    <button className="bedside" onClick={onExit} aria-label="Exit bedside mode">
      <div className="bedside-time">{formatTime(now.getHours(), now.getMinutes(), settings.use24h)}</div>
      <div className="bedside-next">
        {up ? `⏰ ${formatTime(up.alarm.hour, up.alarm.minute, settings.use24h)} · in ${formatCountdown(up.at - now.getTime())}` : "No alarm set"}
      </div>
      <div className="bedside-hint">Tap to exit</div>
    </button>
  );
}
