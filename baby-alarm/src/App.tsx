import { useCallback, useEffect, useRef, useState } from "react";
import type { Alarm, AppState, Settings } from "./lib/types";
import { loadState, makeId, newAlarm, saveState } from "./lib/storage";
import { dueAlarms } from "./lib/scheduler";
import { unlockAudio } from "./lib/audio";
import { AlarmList } from "./components/AlarmList";
import { AlarmEditor } from "./components/AlarmEditor";
import { RingScreen, type RingSession } from "./components/RingScreen";
import { StatsView } from "./components/StatsView";
import { SettingsView } from "./components/SettingsView";
import { VoicePicker } from "./components/VoicePicker";
import { BedsideMode } from "./components/BedsideMode";
import { TabBar, type Tab } from "./components/TabBar";

export function App({ initialState }: { initialState?: AppState }) {
  const [state, setState] = useState<AppState>(() => initialState ?? loadState());
  const [tab, setTab] = useState<Tab>("alarms");
  const [editing, setEditing] = useState<{ alarm: Alarm; isNew: boolean } | null>(null);
  const [ringing, setRinging] = useState<RingSession | null>(null);
  const [snooze, setSnooze] = useState<{ session: RingSession; until: number } | null>(null);
  const [armed, setArmed] = useState(false);
  const [bedside, setBedside] = useState(false);
  const [now, setNow] = useState(() => new Date());
  const prevTick = useRef(new Date());

  // Persist every change.
  useEffect(() => {
    saveState(state);
  }, [state]);

  const ring = useCallback((alarm: Alarm, carry?: RingSession) => {
    setBedside(false);
    setRinging({ alarm, firedAt: carry?.firedAt ?? Date.now(), snoozes: carry?.snoozes ?? 0 });
  }, []);

  // Scheduler tick.
  useEffect(() => {
    const t = setInterval(() => {
      const current = new Date();
      setNow(current);
      const prev = prevTick.current;
      prevTick.current = current;
      if (ringing) return;
      if (snooze && current.getTime() >= snooze.until) {
        setSnooze(null);
        ring(snooze.session.alarm, snooze.session);
        return;
      }
      const due = dueAlarms(state.alarms, prev, current);
      if (due.length > 0) {
        const alarm = due[0];
        ring(alarm);
        if (alarm.repeat.length === 0) {
          setState((s) => ({ ...s, alarms: s.alarms.map((a) => (a.id === alarm.id ? { ...a, enabled: false } : a)) }));
        }
      }
    }, 1000);
    return () => clearInterval(t);
  }, [state.alarms, ringing, snooze, ring]);

  const arm = () => {
    unlockAudio();
    setArmed(true);
  };

  const updateSettings = (settings: Settings) => setState((s) => ({ ...s, settings }));

  const saveAlarm = (alarm: Alarm) => {
    setState((s) => {
      const exists = s.alarms.some((a) => a.id === alarm.id);
      return { ...s, alarms: exists ? s.alarms.map((a) => (a.id === alarm.id ? { ...alarm, enabled: true } : a)) : [...s.alarms, { ...alarm, enabled: true }] };
    });
    setEditing(null);
  };

  const onSnooze = () => {
    if (!ringing) return;
    const session = { ...ringing, snoozes: ringing.snoozes + 1 };
    setSnooze({ session, until: Date.now() + ringing.alarm.snoozeMinutes * 60_000 });
    setRinging(null);
  };

  const ringingRef = useRef(ringing);
  ringingRef.current = ringing;

  const onDismissed = useCallback((failedAttempts: number) => {
    const r = ringingRef.current;
    if (!r) return;
    ringingRef.current = null;
    const record = {
      id: makeId(),
      alarmId: r.alarm.id,
      alarmLabel: r.alarm.label || "Alarm",
      firedAt: r.firedAt,
      dismissedAt: Date.now(),
      snoozes: r.snoozes,
      challenge: r.alarm.challenge,
      soundId: r.alarm.soundId,
      failedAttempts,
    };
    setState((s) => ({ ...s, history: [...s.history, record] }));
    setRinging(null);
    setTab("stats");
  }, []);

  if (ringing) {
    return (
      <div className="app">
        <RingScreen key={`${ringing.alarm.id}-${ringing.firedAt}-${ringing.snoozes}`} session={ringing} settings={state.settings} onSnooze={onSnooze} onDismissed={onDismissed} />
      </div>
    );
  }

  if (bedside) {
    return (
      <div className="app">
        <BedsideMode alarms={state.alarms} settings={state.settings} now={now} onExit={() => setBedside(false)} />
      </div>
    );
  }

  return (
    <div className="app">
      {!armed && (
        <button className="arm-banner" onClick={arm}>
          🔈 Tap to arm alarms — keep this tab open so the baby can wake you
        </button>
      )}
      <main className="content">
        {editing ? (
          <AlarmEditor
            initial={editing.alarm}
            isNew={editing.isNew}
            settings={state.settings}
            onSave={saveAlarm}
            onCancel={() => setEditing(null)}
            onDelete={(id) => {
              setState((s) => ({ ...s, alarms: s.alarms.filter((a) => a.id !== id) }));
              setEditing(null);
            }}
          />
        ) : tab === "alarms" ? (
          <>
            <AlarmList
              alarms={state.alarms}
              settings={state.settings}
              now={now}
              snoozedUntil={snooze?.until ?? null}
              onToggle={(id) => setState((s) => ({ ...s, alarms: s.alarms.map((a) => (a.id === id ? { ...a, enabled: !a.enabled } : a)) }))}
              onEdit={(alarm) => setEditing({ alarm, isNew: false })}
              onAdd={() => setEditing({ alarm: newAlarm(state.settings, { label: "Alarm", repeat: [] }), isNew: true })}
              onTest={(alarm) => {
                arm();
                ring(alarm);
              }}
            />
            <div className="bottom-actions">
              <button className="btn secondary wide" onClick={() => { arm(); setBedside(true); }}>
                🌙 Bedside mode
              </button>
              {snooze && (
                <button className="btn ghost wide" onClick={() => setSnooze(null)}>
                  Cancel snooze
                </button>
              )}
            </div>
          </>
        ) : tab === "voices" ? (
          <section className="screen">
            <header className="screen-header">
              <h1>Baby Voices</h1>
            </header>
            <p className="muted pad">Pick the default cry for new alarms. Each alarm can use its own voice too.</p>
            <VoicePicker
              selectedId={state.settings.defaultSoundId}
              volume={state.settings.volume}
              onSelect={(id) => updateSettings({ ...state.settings, defaultSoundId: id })}
            />
          </section>
        ) : tab === "stats" ? (
          <StatsView history={state.history} now={now} onClear={() => setState((s) => ({ ...s, history: [] }))} />
        ) : (
          <SettingsView settings={state.settings} onChange={updateSettings} />
        )}
      </main>
      {!editing && <TabBar tab={tab} onChange={setTab} />}
    </div>
  );
}
