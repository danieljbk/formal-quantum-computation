import { useCallback } from 'react';
import { missionInfo } from '../core/missions';
import type { Action } from '../core/store';
import type { AppState } from '../core/types';
import { MISSION_COMPONENTS } from '../missions';

export function MissionRunnerView({ state, dispatch }: { state: AppState; dispatch: (a: Action) => void }) {
  const r = state.ringing!;
  const alarm = state.alarms.find((a) => a.id === r.alarmId)!;
  const config = alarm.missions[r.missionIndex];
  const Mission = MISSION_COMPONENTS[config.kind];
  const index = r.missionIndex;
  const onDone = useCallback(() => dispatch({ type: 'MISSION_COMPLETE', now: Date.now(), index }), [dispatch, index]);
  const onActivity = useCallback(() => dispatch({ type: 'MISSION_ACTIVITY', now: Date.now() }), [dispatch]);
  const idleLeft = Math.max(0, Math.ceil(state.settings.missionIdleSeconds - (Date.now() - r.lastActivityAt) / 1000));

  return (
    <div className="ringing mission-mode" role="alertdialog" aria-label="Mission">
      <p className="ring-reason">
        Mission {index + 1} of {alarm.missions.length} · {missionInfo(config.kind).icon} {missionInfo(config.kind).title}
      </p>
      <p className="hint">The crying is quieter while you work. Stop for {idleLeft}s and it comes back at full volume.</p>
      <Mission key={`${index}-${r.seed}`} config={config} seed={r.seed} onDone={onDone} onActivity={onActivity} />
    </div>
  );
}
