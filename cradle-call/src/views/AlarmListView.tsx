import { voiceById } from '../audio/voices';
import { missionInfo } from '../core/missions';
import { describeRepeat, formatCountdown, formatTime, nextOccurrence } from '../core/schedule';
import type { Action } from '../core/store';
import type { AppState } from '../core/types';

const NAP_MINUTES = [10, 20, 30, 60];

export function AlarmListView({ state, now, dispatch }: { state: AppState; now: number; dispatch: (a: Action) => void }) {
  const sorted = [...state.alarms].sort((a, b) => a.hour * 60 + a.minute - (b.hour * 60 + b.minute));
  return (
    <section className="view">
      <div className="view-head">
        <h1>Alarms</h1>
        <button className="primary" onClick={() => dispatch({ type: 'NAVIGATE', screen: 'editor', editingId: null })}>
          + New
        </button>
      </div>

      <div className="card nap">
        <span>Quick nap</span>
        <div className="chips">
          {NAP_MINUTES.map((m) => (
            <button key={m} className="chip" onClick={() => dispatch({ type: 'QUICK_ALARM', now: Date.now(), minutes: m })}>
              {m}m
            </button>
          ))}
        </div>
      </div>

      {sorted.length === 0 && (
        <div className="empty">
          <p className="empty-emoji">👶</p>
          <p>No alarms yet. Add one and a very real baby will make sure you get up.</p>
        </div>
      )}

      <ul className="alarm-list">
        {sorted.map((alarm) => {
          const locked = state.ringing?.alarmId === alarm.id || state.snoozed.some((z) => z.alarmId === alarm.id);
          return (
            <li key={alarm.id} className={`card alarm ${alarm.enabled ? '' : 'off'}`}>
              <button className="alarm-main" onClick={() => dispatch({ type: 'NAVIGATE', screen: 'editor', editingId: alarm.id })}>
                <span className="alarm-time">{formatTime(alarm.hour, alarm.minute, state.settings.use24h)}</span>
                <span className="alarm-meta">
                  {alarm.label} · {describeRepeat(alarm.repeat)}
                </span>
                <span className="alarm-meta">
                  👶 {voiceById(alarm.voiceId).name} · {alarm.missions.map((m) => missionInfo(m.kind).icon).join(' ')}
                  {alarm.enabled && ` · in ${formatCountdown(nextOccurrence(alarm, new Date(now)).getTime() - now)}`}
                </span>
              </button>
              <label className="switch" title={locked ? 'Locked while ringing or snoozed' : 'Toggle alarm'}>
                <input
                  type="checkbox"
                  aria-label={`toggle ${alarm.label}`}
                  checked={alarm.enabled}
                  disabled={locked}
                  onChange={() => dispatch({ type: 'TOGGLE_ALARM', id: alarm.id })}
                />
                <span />
              </label>
            </li>
          );
        })}
      </ul>
    </section>
  );
}
