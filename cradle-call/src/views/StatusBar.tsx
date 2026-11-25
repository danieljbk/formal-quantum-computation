import { escalationAt } from '../core/escalation';
import { formatCountdown, formatTime, nextEnabledAlarm } from '../core/schedule';
import { activeWakeCheck } from '../core/store';
import type { AppState } from '../core/types';

/** Live status surface: always shows what the alarm system is doing right now. */
export function StatusBar({ state, now }: { state: AppState; now: number }) {
  const clock = new Date(now);
  const time = formatTime(clock.getHours(), clock.getMinutes(), state.settings.use24h);
  let status: string;
  let tone = 'idle';
  const wc = activeWakeCheck(state);
  if (state.ringing) {
    const level = escalationAt((now - state.ringing.startedAt) / 1000);
    status = state.ringing.phase === 'mission' ? 'Mission in progress — cry ducked' : `Ringing · ${level.stage.name}`;
    tone = 'ringing';
  } else if (wc?.deadline) {
    status = `Wake-up check · ${formatCountdown(wc.deadline - now)} to confirm`;
    tone = 'warn';
  } else if (state.snoozed.length > 0) {
    const z = state.snoozed.reduce((a, b) => (a.until < b.until ? a : b));
    status = `Snoozed · rings again in ${formatCountdown(z.until - now)}`;
    tone = 'warn';
  } else {
    const next = nextEnabledAlarm(state.alarms, clock);
    status = next ? `Next: ${next.alarm.label} in ${formatCountdown(next.at.getTime() - now)}` : 'No alarms set';
  }
  return (
    <header className={`status-bar ${tone}`} role="status" aria-live="polite">
      <span className="status-clock">{time}</span>
      <span className="status-text">{status}</span>
    </header>
  );
}
