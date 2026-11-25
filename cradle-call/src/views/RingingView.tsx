import { voiceById } from '../audio/voices';
import { escalationAt, STAGES } from '../core/escalation';
import { missionInfo } from '../core/missions';
import { formatTime } from '../core/schedule';
import { canSnooze, type Action } from '../core/store';
import type { AppState } from '../core/types';
import { MissionRunnerView } from './MissionRunnerView';

/**
 * Full-screen takeover while an alarm rings. There is deliberately no
 * "dismiss" or "stop" control: the only ways out are the alarm's missions,
 * or a limited snooze that brings the baby back later.
 */
export function RingingView({ state, now, dispatch }: { state: AppState; now: number; dispatch: (a: Action) => void }) {
  const r = state.ringing!;
  const alarm = state.alarms.find((a) => a.id === r.alarmId);
  if (!alarm) return null;
  const level = escalationAt((now - r.startedAt) / 1000, alarm.maxVolume, r.phase === 'mission');
  const clock = new Date(now);
  const snoozesLeft = alarm.snoozeLimit - r.snoozesUsed;

  if (r.phase === 'mission') return <MissionRunnerView state={state} dispatch={dispatch} />;

  return (
    <div className={`ringing stage-${level.stageIndex}`} role="alertdialog" aria-label="Alarm ringing">
      <p className="ring-reason">
        {r.reason === 'wakeCheck' ? "You didn't confirm you were up." : r.reason === 'test' ? 'Test ring' : alarm.label}
      </p>
      <p className="ring-clock">{formatTime(clock.getHours(), clock.getMinutes(), state.settings.use24h)}</p>
      <p className="ring-baby" aria-hidden>{['🥺', '😣', '😭', '😭😭😭'][level.stageIndex]}</p>
      <p className="ring-voice">{voiceById(alarm.voiceId).name} is crying</p>

      <ol className="stages" aria-label="escalation">
        {STAGES.map((s, i) => (
          <li key={s.name} className={i <= level.stageIndex ? 'reached' : ''}>
            {s.name}
          </li>
        ))}
      </ol>
      <div className="bar"><div className="bar-fill" style={{ width: `${Math.round(level.progress * 100)}%` }} /></div>

      <button className="primary big" onClick={() => dispatch({ type: 'START_MISSIONS', now: Date.now() })}>
        Soothe the baby · {alarm.missions.map((m) => missionInfo(m.kind).icon).join(' ')}
      </button>
      {canSnooze(state) ? (
        <button className="ghost" onClick={() => dispatch({ type: 'SNOOZE', now: Date.now() })}>
          Snooze {alarm.snoozeMinutes} min ({snoozesLeft} left)
        </button>
      ) : (
        <p className="hint">{alarm.snoozeLimit === 0 ? 'Snooze is off for this alarm.' : 'No snoozes left.'}</p>
      )}
    </div>
  );
}
