import type { WakeRecord } from '../types';
import { wakeStats } from '../engine';
import { MISSION_INFO } from '../missions';
import { formatTime } from '../schedule';

interface Props {
  history: WakeRecord[];
  use24h: boolean;
  onClear: () => void;
}

/** Morning report: how quickly you got up and how often you snoozed. */
export function WakeLog({ history, use24h, onClear }: Props) {
  const stats = wakeStats(history);
  const recent = [...history].reverse().slice(0, 20);
  return (
    <section className="panel">
      <h2 className="panel-title">Wake-up report</h2>
      <div className="stats">
        <div className="stat">
          <span className="stat-num">{stats.count}</span>
          <span className="stat-label">mornings</span>
        </div>
        <div className="stat">
          <span className="stat-num">{stats.avgDelayMin}</span>
          <span className="stat-label">avg min to get up</span>
        </div>
        <div className="stat">
          <span className="stat-num">{stats.snoozes}</span>
          <span className="stat-label">snoozes</span>
        </div>
        <div className="stat">
          <span className="stat-num">{stats.streak}</span>
          <span className="stat-label">no-snooze streak</span>
        </div>
      </div>
      {recent.length === 0 ? (
        <p className="muted center">Your mornings will show up here.</p>
      ) : (
        <ul className="log">
          {recent.map((r, i) => {
            const d = new Date(r.dismissedAt);
            const { time, meridiem } = formatTime(d.getHours(), d.getMinutes(), use24h);
            return (
              <li key={`${r.dismissedAt}-${i}`} className="log-row">
                <span>
                  {d.toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })} · {r.label || 'Alarm'}
                </span>
                <span className="muted">
                  up {time} {meridiem} · {MISSION_INFO[r.mission].emoji} · {r.snoozeCount} snooze{r.snoozeCount === 1 ? '' : 's'}
                </span>
              </li>
            );
          })}
        </ul>
      )}
      {history.length > 0 && (
        <button type="button" className="link danger" onClick={onClear}>
          Clear history
        </button>
      )}
    </section>
  );
}
