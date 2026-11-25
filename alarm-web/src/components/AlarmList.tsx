import type { Alarm } from '../types';
import { describeRepeat, formatTime } from '../schedule';
import { getVoice } from '../sounds';
import { MISSION_INFO } from '../missions';

interface Props {
  alarms: Alarm[];
  use24h: boolean;
  onToggle: (id: string, enabled: boolean) => void;
  onEdit: (alarm: Alarm) => void;
  onDelete: (id: string) => void;
}

export function AlarmList({ alarms, use24h, onToggle, onEdit, onDelete }: Props) {
  if (alarms.length === 0) {
    return (
      <div className="empty">
        <div className="empty-emoji">🍼</div>
        <p>No alarms yet.</p>
        <p className="muted">Tap + to choose a time and a baby to wake you.</p>
      </div>
    );
  }
  const sorted = [...alarms].sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
  return (
    <ul className="alarm-list">
      {sorted.map((a) => {
        const { time, meridiem } = formatTime(a.hour, a.minute, use24h);
        return (
          <li key={a.id} className={`alarm ${a.enabled ? '' : 'off'}`}>
            <button type="button" className="alarm-body" onClick={() => onEdit(a)} aria-label={`Edit ${a.label || 'alarm'} at ${time} ${meridiem}`}>
              <div className="alarm-time">
                {time}
                <span className="meridiem">{meridiem}</span>
              </div>
              <div className="alarm-meta">
                {a.label || 'Alarm'}, {describeRepeat(a.repeatDays)}
              </div>
              <div className="alarm-chips">
                <span className="chip">👶 {getVoice(a.sound).name}</span>
                <span className="chip">
                  {MISSION_INFO[a.mission.kind].emoji} {MISSION_INFO[a.mission.kind].title}
                </span>
                {a.wakeUpCheck.enabled && <span className="chip">✅ Wake check</span>}
              </div>
            </button>
            <div className="alarm-actions">
              <label className="switch">
                <input
                  type="checkbox"
                  checked={a.enabled}
                  onChange={(e) => onToggle(a.id, e.target.checked)}
                  aria-label={`${a.label || 'Alarm'} on`}
                />
                <span className="slider" />
              </label>
              <button type="button" className="link danger small" onClick={() => onDelete(a.id)} aria-label={`Delete ${a.label || 'alarm'}`}>
                Delete
              </button>
            </div>
          </li>
        );
      })}
    </ul>
  );
}
