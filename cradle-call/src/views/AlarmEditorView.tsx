import { useState } from 'react';
import { WEEKDAY_SHORT } from '../core/schedule';
import { makeAlarm, type Action } from '../core/store';
import type { Alarm, AppState, Weekday } from '../core/types';
import { MissionPickerView } from './MissionPickerView';
import { VoicePickerView } from './VoicePickerView';

export function AlarmEditorView({ state, dispatch }: { state: AppState; dispatch: (a: Action) => void }) {
  const existing = state.alarms.find((a) => a.id === state.editingId);
  const [draft, setDraft] = useState<Alarm>(() => existing ?? makeAlarm(Date.now(), {}, state.settings.defaultVoiceId));
  const set = (patch: Partial<Alarm>) => setDraft((d) => ({ ...d, ...patch }));
  const locked = !!existing && (state.ringing?.alarmId === existing.id || state.snoozed.some((z) => z.alarmId === existing.id));
  const toggleDay = (d: Weekday) => set({ repeat: draft.repeat.includes(d) ? draft.repeat.filter((x) => x !== d) : [...draft.repeat, d] });
  const time = `${String(draft.hour).padStart(2, '0')}:${String(draft.minute).padStart(2, '0')}`;

  return (
    <section className="view editor">
      <div className="view-head">
        <button onClick={() => dispatch({ type: 'NAVIGATE', screen: 'alarms' })}>Cancel</button>
        <h1>{existing ? 'Edit alarm' : 'New alarm'}</h1>
        <button className="primary" onClick={() => dispatch({ type: 'SAVE_ALARM', alarm: { ...draft, createdAt: existing ? draft.createdAt : Date.now() } })}>
          Save
        </button>
      </div>

      <input
        className="time-input"
        type="time"
        aria-label="alarm time"
        value={time}
        onChange={(e) => {
          const [h, m] = e.target.value.split(':').map(Number);
          if (!Number.isNaN(h) && !Number.isNaN(m)) set({ hour: h, minute: m });
        }}
      />

      <label className="field">
        Label
        <input value={draft.label} maxLength={40} onChange={(e) => set({ label: e.target.value })} />
      </label>

      <fieldset className="field">
        <legend>Repeat</legend>
        <div className="chips">
          {WEEKDAY_SHORT.map((name, d) => (
            <button key={name} className={`chip ${draft.repeat.includes(d as Weekday) ? 'on' : ''}`} aria-pressed={draft.repeat.includes(d as Weekday)} onClick={() => toggleDay(d as Weekday)}>
              {name}
            </button>
          ))}
        </div>
      </fieldset>

      <fieldset className="field">
        <legend>Baby voice</legend>
        <VoicePickerView value={draft.voiceId} onChange={(voiceId) => set({ voiceId })} />
      </fieldset>

      <fieldset className="field">
        <legend>Missions to dismiss</legend>
        <MissionPickerView value={draft.missions} onChange={(missions) => set({ missions })} />
      </fieldset>

      <fieldset className="field grid2">
        <legend>Snooze</legend>
        <label>
          Max snoozes
          <input type="number" min={0} max={10} value={draft.snoozeLimit} onChange={(e) => set({ snoozeLimit: Number(e.target.value) })} />
        </label>
        <label>
          Minutes
          <input type="number" min={1} max={30} value={draft.snoozeMinutes} onChange={(e) => set({ snoozeMinutes: Number(e.target.value) })} />
        </label>
      </fieldset>

      <fieldset className="field grid2">
        <legend>Wake-up check</legend>
        <label className="inline">
          <input type="checkbox" checked={draft.wakeCheck} onChange={(e) => set({ wakeCheck: e.target.checked })} /> Ask if I'm still up
        </label>
        <label>
          After (min)
          <input type="number" min={1} max={30} value={draft.wakeCheckMinutes} onChange={(e) => set({ wakeCheckMinutes: Number(e.target.value) })} />
        </label>
      </fieldset>

      <fieldset className="field grid2">
        <legend>Sound</legend>
        <label>
          Max volume
          <input type="range" min={0.1} max={1} step={0.05} value={draft.maxVolume} onChange={(e) => set({ maxVolume: Number(e.target.value) })} />
        </label>
        <label className="inline">
          <input type="checkbox" checked={draft.vibrate} onChange={(e) => set({ vibrate: e.target.checked })} /> Vibrate
        </label>
      </fieldset>

      {existing && (
        <div className="editor-actions">
          <button disabled={!!state.ringing} onClick={() => dispatch({ type: 'TEST_ALARM', id: existing.id, now: Date.now() })}>
            Test this alarm
          </button>
          <button className="danger" disabled={locked} onClick={() => dispatch({ type: 'DELETE_ALARM', id: existing.id })}>
            Delete
          </button>
        </div>
      )}
    </section>
  );
}
