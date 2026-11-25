import { useEffect, useReducer, useRef, useState } from 'react';
import { audioEngine } from './audio/engine';
import { VOICE_IDS } from './audio/voices';
import { escalationAt, layerVoices } from './core/escalation';
import { activeWakeCheck, loadState, reducer, saveState } from './core/store';
import { AlarmEditorView } from './views/AlarmEditorView';
import { AlarmListView } from './views/AlarmListView';
import { BriefingView } from './views/BriefingView';
import { HistoryView } from './views/HistoryView';
import { RingingView } from './views/RingingView';
import { SettingsView } from './views/SettingsView';
import { StatusBar } from './views/StatusBar';
import { TabBar } from './views/TabBar';
import { WakeCheckView } from './views/WakeCheckView';

const storage = typeof window !== 'undefined' ? window.localStorage : undefined;

type WakeLockSentinelLike = { release: () => Promise<void> };

export function App() {
  const [state, dispatch] = useReducer(reducer, undefined, () => loadState(storage));
  const [now, setNow] = useState(() => Date.now());
  const vibrating = useRef(false);

  // Scheduler heartbeat.
  useEffect(() => {
    const id = setInterval(() => {
      const t = Date.now();
      setNow(t);
      dispatch({ type: 'TICK', now: t });
    }, 1000);
    return () => clearInterval(id);
  }, []);

  useEffect(() => saveState(storage, state), [state]);

  // First tap anywhere unlocks audio (browser autoplay rules).
  useEffect(() => {
    const unlock = () => void audioEngine.unlock();
    window.addEventListener('pointerdown', unlock, { once: true });
    window.addEventListener('keydown', unlock, { once: true });
    audioEngine.preload(VOICE_IDS.slice(0, 3));
    return () => {
      window.removeEventListener('pointerdown', unlock);
      window.removeEventListener('keydown', unlock);
    };
  }, []);

  // Keep the screen (and therefore the page's timers) alive while an alarm is armed.
  const armed = state.alarms.some((a) => a.enabled) || state.snoozed.length > 0 || state.wakeChecks.length > 0;
  useEffect(() => {
    if (!armed || typeof navigator === 'undefined' || !('wakeLock' in navigator)) return;
    let lock: WakeLockSentinelLike | null = null;
    const nav = navigator as unknown as { wakeLock: { request: (t: 'screen') => Promise<WakeLockSentinelLike> } };
    const acquire = () => {
      if (document.visibilityState === 'visible') nav.wakeLock.request('screen').then((l) => (lock = l)).catch(() => undefined);
    };
    acquire();
    document.addEventListener('visibilitychange', acquire);
    return () => {
      document.removeEventListener('visibilitychange', acquire);
      void lock?.release();
    };
  }, [armed]);

  // Drive the escalating cry from the ringing state.
  const ringing = state.ringing;
  const ringingAlarm = ringing ? state.alarms.find((a) => a.id === ringing.alarmId) : undefined;
  useEffect(() => {
    if (!ringing || !ringingAlarm) {
      audioEngine.stop();
      if (vibrating.current) audioEngine.vibrate(false);
      vibrating.current = false;
      return;
    }
    const level = escalationAt((now - ringing.startedAt) / 1000, ringingAlarm.maxVolume, ringing.phase === 'mission');
    audioEngine.setLayers(layerVoices(ringingAlarm.voiceId, VOICE_IDS, level.layers), level.volume);
    const shouldVibrate = ringingAlarm.vibrate && level.vibrate;
    if (shouldVibrate && now % 3000 < 1000) audioEngine.vibrate(true);
    vibrating.current = shouldVibrate;
  }, [ringing, ringingAlarm, now]);

  useEffect(() => {
    document.title = ringing ? '😭 Wake up! · Cradle Call' : 'Cradle Call';
  }, [ringing]);

  const wakeCheck = activeWakeCheck(state);

  let body;
  if (ringing) body = <RingingView state={state} now={now} dispatch={dispatch} />;
  else if (wakeCheck?.deadline) body = <WakeCheckView deadline={wakeCheck.deadline} now={now} dispatch={dispatch} />;
  else if (state.screen === 'editor') body = <AlarmEditorView key={state.editingId ?? 'new'} state={state} dispatch={dispatch} />;
  else if (state.screen === 'history') body = <HistoryView state={state} dispatch={dispatch} />;
  else if (state.screen === 'settings') body = <SettingsView state={state} dispatch={dispatch} />;
  else if (state.screen === 'briefing') body = <BriefingView state={state} now={now} dispatch={dispatch} />;
  else body = <AlarmListView state={state} now={now} dispatch={dispatch} />;

  const takeover = !!ringing || !!wakeCheck?.deadline;
  return (
    <div className="app">
      <StatusBar state={state} now={now} />
      <main>{body}</main>
      {!takeover && state.screen !== 'editor' && state.screen !== 'briefing' && (
        <TabBar screen={state.screen} onNavigate={(screen) => dispatch({ type: 'NAVIGATE', screen })} />
      )}
    </div>
  );
}
