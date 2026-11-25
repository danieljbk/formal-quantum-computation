import type { Alarm, Settings } from "../lib/types";
import { describeRepeat, formatCountdown, formatTime, nextAlarm } from "../lib/scheduler";
import { CHALLENGES } from "../lib/challenges";
import { soundById } from "../data/sounds";

interface Props {
  alarms: Alarm[];
  settings: Settings;
  now: Date;
  snoozedUntil: number | null;
  onToggle: (id: string) => void;
  onEdit: (alarm: Alarm) => void;
  onAdd: () => void;
  onTest: (alarm: Alarm) => void;
}

export function AlarmList({ alarms, settings, now, snoozedUntil, onToggle, onEdit, onAdd, onTest }: Props) {
  const upcoming = nextAlarm(alarms, now);
  const sorted = [...alarms].sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));

  return (
    <section className="screen">
      <header className="screen-header">
        <h1>Alarms</h1>
        <button className="icon-btn" onClick={onAdd} aria-label="Add alarm">
          ＋
        </button>
      </header>

      <div className="next-card">
        {snoozedUntil ? (
          <>
            <div className="muted">Snoozed — the baby cries again in</div>
            <div className="next-in">{formatCountdown(snoozedUntil - now.getTime())}</div>
          </>
        ) : upcoming ? (
          <>
            <div className="muted">Next cry in</div>
            <div className="next-in">{formatCountdown(upcoming.at - now.getTime())}</div>
            <div className="muted small">
              {upcoming.alarm.label} · {soundById(upcoming.alarm.soundId).name}
            </div>
          </>
        ) : (
          <div className="muted">No alarms on. Enjoy the quiet.</div>
        )}
      </div>

      {sorted.length === 0 && <p className="empty">Tap ＋ to add your first baby alarm.</p>}
      <ul className="alarm-list">
        {sorted.map((a) => (
          <li key={a.id} className={`alarm-row ${a.enabled ? "" : "off"}`}>
            <button className="alarm-main" onClick={() => onEdit(a)} aria-label={`Edit ${a.label}`}>
              <div className="alarm-time">{formatTime(a.hour, a.minute, settings.use24h)}</div>
              <div className="alarm-meta">
                {a.label || "Alarm"} · {describeRepeat(a.repeat)}
              </div>
              <div className="alarm-meta small">
                👶 {soundById(a.soundId).name} · {CHALLENGES[a.challenge].emoji} {CHALLENGES[a.challenge].name}
              </div>
            </button>
            <div className="alarm-actions">
              <button className="chip" onClick={() => onTest(a)} aria-label={`Ring ${a.label} now`}>
                ▶︎ Test
              </button>
              <label className="switch">
                <input type="checkbox" checked={a.enabled} onChange={() => onToggle(a.id)} aria-label={`Enable ${a.label}`} />
                <span className="slider" />
              </label>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
