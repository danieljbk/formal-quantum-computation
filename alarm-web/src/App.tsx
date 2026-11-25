import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import type { Alarm, PersistedState } from './types';
import { browserStore, createAlarm, loadState, saveState } from './storage';
import { IDLE, canSnooze, confirmAwake, dismiss, markFired, snooze, tick, type RingPhase } from './engine';
import { formatCountdown, formatTime, nextRing } from './schedule';
import { CryPlayer } from './audio';
import { AlarmList } from './components/AlarmList';
import { AlarmEditor } from './components/AlarmEditor';
import { RingingScreen } from './components/RingingScreen';
import { QuickAlarm } from './components/QuickAlarm';
import { WakeLog } from './components/WakeLog';
import { SettingsPanel } from './components/SettingsPanel';

type Tab = 'alarms' | 'quick' | 'report' | 'settings';

interface WakeLockSentinelLike {
  release(): Promise<void>;
}

export function App() {
  const store = useMemo(browserStore, []);
  const [state, setState] = useState<PersistedState>(() => loadState(store));
  const [phase, setPhase] = useState<RingPhase>(IDLE);
  const [now, setNow] = useState(() => Date.now());
  const [tab, setTab] = useState<Tab>('alarms');
  const [editing, setEditing] = useState<{ alarm: Alarm; isNew: boolean } | null>(null);
  const [bedside, setBedside] = useState(false);
  const player = useMemo(() => new CryPlayer(), []);
  const wakeLock = useRef<WakeLockSentinelLike | null>(null);

  // Persist on every change.
  useEffect(() => saveState(store, state), [store, state]);

  // iOS needs a user gesture before audio may play later; unlock on the first tap.
  useEffect(() => {
    const unlock = () => {
      player.unlock();
      window.removeEventListener('pointerdown', unlock);
    };
    window.addEventListener('pointerdown', unlock);
    return () => window.removeEventListener('pointerdown', unlock);
  }, [player]);

  // The clock: advance the ring state machine every second.
  useEffect(() => {
    const id = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(id);
  }, []);

  useEffect(() => {
    const result = tick(phase, state.alarms, now);
    if (result.phase !== phase) setPhase(result.phase);
    if (result.fired.length) setState((s) => ({ ...s, alarms: markFired(s.alarms, result.fired, now) }));
  }, [now, phase, state.alarms]);

  const ringingAlarm = phase.kind !== 'idle' ? state.alarms.find((a) => a.id === phase.alarmId) : undefined;
  const isRinging = phase.kind === 'ringing';

  // If the alarm behind the current phase was deleted, drop back to idle.
  useEffect(() => {
    if (phase.kind !== 'idle' && !ringingAlarm) setPhase(IDLE);
  }, [phase, ringingAlarm]);

  // Start / stop the crying when the phase changes.
  useEffect(() => {
    if (isRinging && ringingAlarm) {
      setEditing(null);
      player.play(ringingAlarm.sound, {
        volume: ringingAlarm.volume,
        fadeInSeconds: ringingAlarm.fadeInSeconds,
        vibrate: ringingAlarm.vibrate,
      });
    } else if (!isRinging) {
      player.stop();
    }
    // Only react to entering/leaving the ringing phase, not to every alarm edit.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isRinging, phase.kind === 'ringing' ? phase.startedAt : 0]);

  // Bedside mode keeps the screen on so the page is alive when the alarm is due.
  useEffect(() => {
    const nav = navigator as Navigator & { wakeLock?: { request(type: 'screen'): Promise<WakeLockSentinelLike> } };
    if (!bedside || !nav.wakeLock) return;
    let cancelled = false;
    const acquire = () =>
      nav.wakeLock!.request('screen').then((s) => {
        if (cancelled) void s.release();
        else wakeLock.current = s;
      }).catch(() => undefined);
    void acquire();
    const onVisible = () => document.visibilityState === 'visible' && void acquire();
    document.addEventListener('visibilitychange', onVisible);
    return () => {
      cancelled = true;
      document.removeEventListener('visibilitychange', onVisible);
      void wakeLock.current?.release();
      wakeLock.current = null;
    };
  }, [bedside]);

  const upsert = useCallback((alarm: Alarm) => {
    setState((s) => {
      const exists = s.alarms.some((a) => a.id === alarm.id);
      return { ...s, alarms: exists ? s.alarms.map((a) => (a.id === alarm.id ? alarm : a)) : [...s.alarms, alarm] };
    });
  }, []);

  const remove = useCallback((id: string) => {
    setState((s) => ({ ...s, alarms: s.alarms.filter((a) => a.id !== id) }));
  }, []);

  const onDismiss = () => {
    const res = dismiss(phase, ringingAlarm, Date.now());
    setPhase(res.phase);
    if (res.record) setState((s) => ({ ...s, history: [...s.history, res.record!] }));
  };

  const upcoming = nextRing(state.alarms, now);
  const fmt = (t: number) => {
    const d = new Date(t);
    const { time, meridiem } = formatTime(d.getHours(), d.getMinutes(), state.settings.use24h);
    return `${time}${meridiem ? ` ${meridiem}` : ''}`;
  };

  return (
    <div className="app">
      <header className="top">
        <div>
          <h1>{tab === 'alarms' ? 'Alarms' : tab === 'quick' ? 'Nap' : tab === 'report' ? 'Report' : 'Settings'}</h1>
          <p className="subtitle">
            {upcoming ? `${formatCountdown(upcoming.at - now)} · ${fmt(upcoming.at)}` : 'No alarms on'}
          </p>
        </div>
        <div className="top-actions">
          <button
            type="button"
            className={`pill ${bedside ? 'on' : ''}`}
            aria-pressed={bedside}
            onClick={() => setBedside((b) => !b)}
            title="Keep the screen awake so the alarm can ring"
          >
            🌙 Bedside
          </button>
          {tab === 'alarms' && (
            <button
              type="button"
              className="add-btn"
              aria-label="Add alarm"
              onClick={() => setEditing({ alarm: createAlarm({ sound: state.settings.defaultSound, label: 'Alarm' }), isNew: true })}
            >
              +
            </button>
          )}
        </div>
      </header>

      {phase.kind === 'snoozed' && (
        <div className="banner">
          <span>💤 Snoozed until {fmt(phase.until)}</span>
          <button type="button" className="link strong" onClick={() => setPhase({ ...phase, until: Date.now() })}>
            Wake now
          </button>
        </div>
      )}
      {phase.kind === 'awaitingCheck' && (
        <div className="banner">
          <span>✅ Wake-up check at {fmt(phase.checkAt)}</span>
          <button type="button" className="link strong" onClick={() => setPhase(confirmAwake(phase))}>
            I'm up for good
          </button>
        </div>
      )}

      <main className="content">
        {tab === 'alarms' && (
          <AlarmList
            alarms={state.alarms}
            use24h={state.settings.use24h}
            onToggle={(id, enabled) =>
              setState((s) => ({
                ...s,
                alarms: s.alarms.map((a) => (a.id === id ? { ...a, enabled, lastFiredAt: enabled ? undefined : a.lastFiredAt } : a)),
              }))
            }
            onEdit={(alarm) => setEditing({ alarm, isNew: false })}
            onDelete={remove}
          />
        )}
        {tab === 'quick' && (
          <QuickAlarm
            onCreate={(minutes) => {
              const at = Date.now() + minutes * 60_000;
              const d = new Date(at);
              upsert(
                createAlarm({
                  label: `${minutes}-min nap`,
                  hour: d.getHours(),
                  minute: d.getMinutes(),
                  oneShotAt: at,
                  sound: state.settings.defaultSound,
                  mission: { kind: 'none', difficulty: 'easy', rounds: 1 },
                  fadeInSeconds: 10,
                }),
              );
              setTab('alarms');
            }}
          />
        )}
        {tab === 'report' && (
          <WakeLog history={state.history} use24h={state.settings.use24h} onClear={() => setState((s) => ({ ...s, history: [] }))} />
        )}
        {tab === 'settings' && <SettingsPanel settings={state.settings} onChange={(settings) => setState((s) => ({ ...s, settings }))} />}
      </main>

      <nav className="tabbar" aria-label="Sections">
        {(
          [
            ['alarms', '⏰', 'Alarms'],
            ['quick', '💤', 'Nap'],
            ['report', '📈', 'Report'],
            ['settings', '⚙️', 'Settings'],
          ] as const
        ).map(([id, icon, label]) => (
          <button type="button" key={id} className={`tab ${tab === id ? 'on' : ''}`} aria-current={tab === id} onClick={() => setTab(id)}>
            <span aria-hidden>{icon}</span>
            {label}
          </button>
        ))}
      </nav>

      {editing && (
        <AlarmEditor
          alarm={editing.alarm}
          isNew={editing.isNew}
          player={player}
          onCancel={() => setEditing(null)}
          onSave={(a) => {
            upsert(a);
            setEditing(null);
          }}
          onDelete={() => {
            remove(editing.alarm.id);
            setEditing(null);
          }}
        />
      )}

      {phase.kind === 'ringing' && ringingAlarm && (
        <RingingScreen
          key={phase.startedAt}
          alarm={ringingAlarm}
          use24h={state.settings.use24h}
          canSnooze={canSnooze(phase, ringingAlarm)}
          snoozeCount={phase.snoozeCount}
          recheck={phase.recheck}
          onSnooze={() => setPhase(snooze(phase, ringingAlarm, Date.now()))}
          onDismiss={onDismiss}
        />
      )}

      {phase.kind === 'checking' && (
        <div className="check-modal" role="alertdialog" aria-label="Wake-up check">
          <div className="check-card">
            <div className="empty-emoji">👀</div>
            <h2>Still awake?</h2>
            <p className="muted">
              Answer within {Math.max(0, Math.ceil((phase.deadline - now) / 1000))} s or the baby cries again.
            </p>
            <button type="button" className="primary wide" onClick={() => setPhase(confirmAwake(phase))}>
              I'm awake
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
