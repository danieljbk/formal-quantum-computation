import { useCallback, useState } from "react";
import { formatClock } from "../schedule";
import { voiceById } from "../sounds";
import type { Alarm, Ringing } from "../types";
import { MissionPanel } from "./MissionPanel";

interface Props {
  ringing: Ringing;
  alarm: Alarm;
  now: number;
  snoozesLeft: number;
  onSnooze: () => void;
  onDismiss: () => void;
}

export function RingingScreen({ ringing, alarm, now, snoozesLeft, onSnooze, onDismiss }: Props) {
  const [inMission, setInMission] = useState(false);
  const voice = voiceById(ringing.soundId);
  const d = new Date(now);
  const clock = formatClock(d.getHours(), d.getMinutes());
  const done = useCallback(() => onDismiss(), [onDismiss]);

  const stop = () => {
    if (alarm.mission.kind === "none") onDismiss();
    else setInMission(true);
  };

  return (
    <div className="ringing" role="alertdialog" aria-label="Alarm ringing">
      <div className="ring-top">
        <div className="ring-label">{alarm.label || "Alarm"}</div>
        <div className="ring-clock">
          {clock.time}
          <span className="meridiem">{clock.meridiem}</span>
        </div>
      </div>

      {!inMission ? (
        <>
          <div className="crying" aria-hidden>
            <span className="baby">😭</span>
            <span className="tear t1">💧</span>
            <span className="tear t2">💧</span>
          </div>
          <div className="ring-voice">
            {voice.emoji} {voice.name} is crying
          </div>
          <div className="ring-actions">
            {alarm.snooze.enabled && (
              <button type="button" className="btn snooze" disabled={snoozesLeft <= 0} onClick={onSnooze}>
                {snoozesLeft > 0
                  ? `Snooze ${alarm.snooze.minutes} min · ${snoozesLeft} left`
                  : "No snoozes left"}
              </button>
            )}
            <button type="button" className="btn primary big" onClick={stop}>
              {alarm.mission.kind === "none" ? "I’m up" : "Start mission to stop"}
            </button>
          </div>
        </>
      ) : (
        alarm.mission.kind !== "none" && (
          <>
            <div className="crying small" aria-hidden>
              <span className="baby">😭</span>
            </div>
            <MissionPanel mission={alarm.mission} seed={ringing.firedAt ^ ringing.snoozeCount} onDone={done} />
          </>
        )
      )}
    </div>
  );
}
