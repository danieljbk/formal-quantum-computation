import { useEffect, useState } from 'react';
import type { Alarm } from '../types';
import { formatTime } from '../schedule';
import { getVoice } from '../sounds';
import { MissionPanel } from './MissionPanel';

interface Props {
  alarm: Alarm;
  use24h: boolean;
  canSnooze: boolean;
  snoozeCount: number;
  recheck: boolean;
  onSnooze: () => void;
  onDismiss: () => void;
}

/** Full-screen ring: the baby cries until you snooze or finish the mission. */
export function RingingScreen({ alarm, use24h, canSnooze, snoozeCount, recheck, onSnooze, onDismiss }: Props) {
  const [now, setNow] = useState(() => new Date());
  const [inMission, setInMission] = useState(false);

  useEffect(() => {
    const t = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(t);
  }, []);

  const { time, meridiem } = formatTime(now.getHours(), now.getMinutes(), use24h);
  const needsMission = alarm.mission.kind !== 'none';

  return (
    <div className="ringing" role="alertdialog" aria-label={`${alarm.label || 'Alarm'} is ringing`}>
      {inMission ? (
        <MissionPanel mission={alarm.mission} onComplete={onDismiss} onBack={() => setInMission(false)} />
      ) : (
        <>
          <div className="ring-top">
            <p className="ring-label">{recheck ? "You didn't answer the wake-up check!" : alarm.label || 'Alarm'}</p>
            <div className="ring-time">
              {time}
              <span className="meridiem">{meridiem}</span>
            </div>
            <p className="muted">{now.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</p>
          </div>
          <div className="crying-baby" aria-hidden>
            <span>👶</span>
            <span className="tear t1">💧</span>
            <span className="tear t2">💧</span>
          </div>
          <p className="muted center">{getVoice(alarm.sound).name} is crying…</p>
          <div className="ring-actions">
            {canSnooze && (
              <button type="button" className="snooze-btn" onClick={onSnooze}>
                Snooze {alarm.snooze.minutes} min
                {alarm.snooze.maxCount > 0 && (
                  <span className="small"> · {alarm.snooze.maxCount - snoozeCount} left</span>
                )}
              </button>
            )}
            <button type="button" className="stop-btn" onClick={() => (needsMission ? setInMission(true) : onDismiss())}>
              {needsMission ? 'Start mission to stop' : 'Stop'}
            </button>
          </div>
        </>
      )}
    </div>
  );
}
