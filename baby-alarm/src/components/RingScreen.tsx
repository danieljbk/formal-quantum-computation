import { useCallback, useEffect, useRef, useState } from "react";
import type { Alarm, Settings } from "../lib/types";
import { AlarmPlayer } from "../lib/audio";
import { startVibration, canVibrate } from "../lib/vibration";
import { CHALLENGES } from "../lib/challenges";
import { formatTime } from "../lib/scheduler";
import { soundById } from "../data/sounds";
import { ChallengeHost } from "./challenges/ChallengeHost";

export interface RingSession {
  alarm: Alarm;
  firedAt: number;
  snoozes: number;
}

interface Props {
  session: RingSession;
  settings: Settings;
  onSnooze: () => void;
  onDismissed: (failedAttempts: number) => void;
}

/** Full-screen ringing UI: the baby cries until the wake-up mission is completed. */
export function RingScreen({ session, settings, onSnooze, onDismissed }: Props) {
  const { alarm } = session;
  const [phase, setPhase] = useState<"ringing" | "mission" | "done">("ringing");
  const [blocked, setBlocked] = useState(false);
  const [now, setNow] = useState(new Date());
  const failed = useRef(0);
  const player = useRef(new AlarmPlayer());

  useEffect(() => {
    const p = player.current;
    p.start(alarm.soundId, settings.volume, settings.rampSeconds);
    const stopVib = startVibration(alarm.vibration);
    const check = setTimeout(() => setBlocked(!p.isPlaying), 800);
    const clock = setInterval(() => setNow(new Date()), 1000);
    return () => {
      p.stop();
      stopVib();
      clearTimeout(check);
      clearInterval(clock);
    };
  }, [alarm.soundId, alarm.vibration, settings.volume, settings.rampSeconds]);

  const solved = useCallback(() => {
    player.current.stop();
    setPhase("done");
    setTimeout(() => onDismissed(failed.current), 1600);
  }, [onDismissed]);

  const onFailedAttempt = useCallback(() => {
    failed.current += 1;
  }, []);

  const canSnooze = session.snoozes < alarm.maxSnoozes;
  const sound = soundById(alarm.soundId);
  const challenge = CHALLENGES[alarm.challenge];
  const visualPulse = alarm.vibration !== "off" && !canVibrate();

  return (
    <div className={`ring-screen ${phase === "done" ? "calm" : ""} ${visualPulse ? `pulse-${alarm.vibration}` : ""}`} role="alertdialog" aria-label="Alarm ringing">
      {phase === "done" ? (
        <div className="ring-done">
          <div className="huge-emoji">😴</div>
          <h1>Baby soothed.</h1>
          <p className="muted">Good morning! You're up.</p>
        </div>
      ) : (
        <>
          <header className={`ring-header ${phase === "mission" ? "compact" : ""}`}>
            <div className="ring-time">{formatTime(now.getHours(), now.getMinutes(), settings.use24h)}</div>
            <div className="ring-label">{alarm.label || "Alarm"}</div>
            <div className="ring-sub">
              {sound.name} · {challenge.emoji} {challenge.name}
              {session.snoozes > 0 && ` · snoozed ${session.snoozes}×`}
            </div>
          </header>

          {phase === "ringing" ? (
            <div className="ring-body">
              <div className="crying-baby" aria-hidden>
                😭
              </div>
              {blocked && (
                <button className="btn secondary" onClick={() => { player.current.resume(); setBlocked(false); }}>
                  🔊 Tap to hear the baby
                </button>
              )}
              <button className="btn primary wide big" onClick={() => setPhase("mission")}>
                Soothe the baby
              </button>
              {canSnooze ? (
                <button className="btn ghost wide" onClick={onSnooze}>
                  Snooze {alarm.snoozeMinutes} min ({alarm.maxSnoozes - session.snoozes} left)
                </button>
              ) : (
                <p className="muted center">No snoozes left. Time to get up.</p>
              )}
            </div>
          ) : (
            <div className="ring-body mission">
              <h2 className="mission-title">
                {challenge.emoji} {challenge.name} mission
              </h2>
              <ChallengeHost kind={alarm.challenge} difficulty={alarm.difficulty} onSolved={solved} onFailedAttempt={onFailedAttempt} />
              <button className="btn ghost small" onClick={() => setPhase("ringing")}>
                Back
              </button>
            </div>
          )}
        </>
      )}
    </div>
  );
}
