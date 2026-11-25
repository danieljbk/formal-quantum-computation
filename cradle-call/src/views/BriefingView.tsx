import { voiceById } from '../audio/voices';
import { formatCountdown, formatTime, nextEnabledAlarm } from '../core/schedule';
import { wakeStats, type Action } from '../core/store';
import type { AppState } from '../core/types';

const TIPS = [
  'Drink a glass of water before you look at your phone.',
  'Open the curtains — daylight resets your body clock.',
  'Bed made = no going back in it.',
  'Two minutes of stretching beats ten more minutes of sleep.',
  'Tomorrow-you will thank today-you for setting out clothes tonight.',
];

/** Morning briefing shown after the alarm is dismissed. */
export function BriefingView({ state, now, dispatch }: { state: AppState; now: number; dispatch: (a: Action) => void }) {
  const b = state.briefing;
  const date = new Date(now);
  const hour = date.getHours();
  const greeting = hour < 12 ? 'Good morning' : hour < 18 ? 'Good afternoon' : 'Good evening';
  const stats = wakeStats(state.history);
  const next = nextEnabledAlarm(state.alarms, date);
  const tip = TIPS[date.getDate() % TIPS.length];
  const wc = state.wakeChecks.find((w) => w.deadline === null);

  return (
    <section className="view briefing">
      <p className="ring-baby" aria-hidden>😴→😊</p>
      <h1>{greeting}!</h1>
      <p className="muted">{date.toLocaleDateString(undefined, { weekday: 'long', month: 'long', day: 'numeric' })}</p>
      {b && (
        <div className="card stats">
          <div>
            <strong>{formatCountdown(b.dismissedAt - b.firedAt)}</strong>
            <span>to soothe {voiceById(b.voiceId).name}</span>
          </div>
          <div>
            <strong>{b.snoozes}</strong>
            <span>snoozes</span>
          </div>
          <div>
            <strong>{stats.streak}</strong>
            <span>snooze-free streak</span>
          </div>
        </div>
      )}
      {wc && <p className="card warn">Wake-up check in {formatCountdown(wc.due - now)} — stay up!</p>}
      <p className="card">💡 {tip}</p>
      <p className="muted">
        {next ? `Next alarm: ${next.alarm.label} at ${formatTime(next.alarm.hour, next.alarm.minute, state.settings.use24h)}` : 'No more alarms scheduled.'}
      </p>
      <button className="primary" onClick={() => dispatch({ type: 'NAVIGATE', screen: 'alarms' })}>
        Start the day
      </button>
    </section>
  );
}
