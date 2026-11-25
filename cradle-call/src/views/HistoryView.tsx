import { voiceById } from '../audio/voices';
import { formatCountdown } from '../core/schedule';
import { wakeStats, type Action } from '../core/store';
import type { AppState } from '../core/types';

export function HistoryView({ state, dispatch }: { state: AppState; dispatch: (a: Action) => void }) {
  const stats = wakeStats(state.history);
  return (
    <section className="view">
      <div className="view-head">
        <h1>Wake history</h1>
        {state.history.length > 0 && <button onClick={() => dispatch({ type: 'CLEAR_HISTORY' })}>Clear</button>}
      </div>
      <div className="card stats">
        <div>
          <strong>{stats.count}</strong>
          <span>wake-ups</span>
        </div>
        <div>
          <strong>{formatCountdown(stats.avgSecondsToWake * 1000)}</strong>
          <span>avg to dismiss</span>
        </div>
        <div>
          <strong>{stats.count ? Math.round((stats.snoozeFree / stats.count) * 100) : 0}%</strong>
          <span>snooze-free</span>
        </div>
      </div>
      {state.history.length === 0 ? (
        <p className="empty">Nothing yet. Your first wake-up will show up here.</p>
      ) : (
        <ul className="history">
          {state.history.map((h, i) => (
            <li key={i} className="card">
              <strong>{new Date(h.firedAt).toLocaleString(undefined, { weekday: 'short', hour: 'numeric', minute: '2-digit' })}</strong>
              <span>
                {h.label}
                {h.reason === 'test' ? ' (test)' : h.reason === 'wakeCheck' ? ' (wake-check re-ring)' : ''} · {voiceById(h.voiceId).name}
              </span>
              <span className="muted">
                {formatCountdown(h.dismissedAt - h.firedAt)} to dismiss · {h.snoozes} snooze{h.snoozes === 1 ? '' : 's'} · {h.missions} mission
                {h.missions === 1 ? '' : 's'}
              </span>
            </li>
          ))}
        </ul>
      )}
    </section>
  );
}
