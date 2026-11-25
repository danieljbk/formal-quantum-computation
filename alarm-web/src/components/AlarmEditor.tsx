import { useState } from 'react';
import type { Alarm, Difficulty, MissionKind, Weekday } from '../types';
import { WEEKDAYS, WEEKDAY_SHORT, describeRepeat, formatCountdown, nextOccurrence } from '../schedule';
import { MISSION_INFO } from '../missions';
import type { CryPlayer } from '../audio';
import { SoundPicker } from './SoundPicker';

interface Props {
  alarm: Alarm;
  isNew: boolean;
  player: CryPlayer;
  onSave: (alarm: Alarm) => void;
  onCancel: () => void;
  onDelete?: () => void;
}

const MISSION_KINDS: MissionKind[] = ['none', 'math', 'shake', 'typing', 'memory', 'tap'];
const DIFFICULTIES: Difficulty[] = ['easy', 'medium', 'hard'];

function toTimeValue(h: number, m: number): string {
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

export function AlarmEditor({ alarm, isNew, player, onSave, onCancel, onDelete }: Props) {
  const [draft, setDraft] = useState<Alarm>(alarm);
  const set = <K extends keyof Alarm>(key: K, value: Alarm[K]) => setDraft((d) => ({ ...d, [key]: value }));

  const toggleDay = (day: Weekday) =>
    set('repeatDays', draft.repeatDays.includes(day) ? draft.repeatDays.filter((d) => d !== day) : [...draft.repeatDays, day].sort());

  const countdown = formatCountdown(nextOccurrence({ ...draft, oneShotAt: undefined }, Date.now()) - Date.now());

  const close = (fn: () => void) => {
    player.stop();
    fn();
  };

  return (
    <div className="sheet" role="dialog" aria-modal="true" aria-label={isNew ? 'Add alarm' : 'Edit alarm'}>
      <header className="sheet-header">
        <button type="button" className="link" onClick={() => close(onCancel)}>
          Cancel
        </button>
        <h2>{isNew ? 'Add Alarm' : 'Edit Alarm'}</h2>
        <button
          type="button"
          className="link strong"
          onClick={() => close(() => onSave({ ...draft, enabled: true, oneShotAt: undefined, lastFiredAt: undefined }))}
        >
          Save
        </button>
      </header>

      <div className="sheet-body">
        <div className="time-picker">
          <input
            type="time"
            aria-label="Alarm time"
            value={toTimeValue(draft.hour, draft.minute)}
            onChange={(e) => {
              const [h, m] = e.target.value.split(':').map(Number);
              if (Number.isFinite(h) && Number.isFinite(m)) setDraft((d) => ({ ...d, hour: h, minute: m }));
            }}
          />
          <p className="muted center">{countdown}</p>
        </div>

        <h3 className="section-title">Repeat · {describeRepeat(draft.repeatDays)}</h3>
        <div className="days">
          {WEEKDAYS.map((d) => (
            <button
              type="button"
              key={d}
              className={`day ${draft.repeatDays.includes(d) ? 'on' : ''}`}
              aria-pressed={draft.repeatDays.includes(d)}
              onClick={() => toggleDay(d)}
            >
              {WEEKDAY_SHORT[d][0]}
              <span className="sr-only">{WEEKDAY_SHORT[d]}</span>
            </button>
          ))}
        </div>

        <div className="group">
          <label className="row">
            <span>Label</span>
            <input
              className="text-input"
              value={draft.label}
              maxLength={40}
              placeholder="Alarm"
              onChange={(e) => set('label', e.target.value)}
            />
          </label>
        </div>

        <h3 className="section-title">Baby voice</h3>
        <SoundPicker value={draft.sound} volume={draft.volume} player={player} onChange={(id) => set('sound', id)} />

        <div className="group">
          <label className="row">
            <span>Volume</span>
            <input
              type="range"
              min={0.1}
              max={1}
              step={0.05}
              value={draft.volume}
              onChange={(e) => set('volume', Number(e.target.value))}
              aria-label="Volume"
            />
          </label>
          <label className="row">
            <span>Gradually louder</span>
            <select value={draft.fadeInSeconds} onChange={(e) => set('fadeInSeconds', Number(e.target.value))}>
              <option value={0}>Off</option>
              <option value={10}>10 s</option>
              <option value={20}>20 s</option>
              <option value={30}>30 s</option>
              <option value={60}>60 s</option>
            </select>
          </label>
          <label className="row">
            <span>Vibrate</span>
            <input type="checkbox" checked={draft.vibrate} onChange={(e) => set('vibrate', e.target.checked)} />
          </label>
        </div>

        <h3 className="section-title">Wake-up mission</h3>
        <div className="mission-grid">
          {MISSION_KINDS.map((k) => (
            <button
              type="button"
              key={k}
              className={`mission-tile ${draft.mission.kind === k ? 'on' : ''}`}
              aria-pressed={draft.mission.kind === k}
              onClick={() => set('mission', { ...draft.mission, kind: k })}
            >
              <span className="mission-emoji">{MISSION_INFO[k].emoji}</span>
              {MISSION_INFO[k].title}
            </button>
          ))}
        </div>
        <p className="muted small pad">{MISSION_INFO[draft.mission.kind].blurb}</p>
        {draft.mission.kind !== 'none' && (
          <div className="group">
            <label className="row">
              <span>Difficulty</span>
              <select
                value={draft.mission.difficulty}
                onChange={(e) => set('mission', { ...draft.mission, difficulty: e.target.value as Difficulty })}
              >
                {DIFFICULTIES.map((d) => (
                  <option key={d} value={d}>
                    {d[0].toUpperCase() + d.slice(1)}
                  </option>
                ))}
              </select>
            </label>
            {(draft.mission.kind === 'math' || draft.mission.kind === 'typing' || draft.mission.kind === 'memory') && (
              <label className="row">
                <span>Rounds</span>
                <select
                  value={draft.mission.rounds}
                  onChange={(e) => set('mission', { ...draft.mission, rounds: Number(e.target.value) })}
                >
                  {[1, 2, 3, 4, 5].map((n) => (
                    <option key={n} value={n}>
                      {n}
                    </option>
                  ))}
                </select>
              </label>
            )}
          </div>
        )}

        <h3 className="section-title">Snooze</h3>
        <div className="group">
          <label className="row">
            <span>Allow snooze</span>
            <input
              type="checkbox"
              checked={draft.snooze.enabled}
              onChange={(e) => set('snooze', { ...draft.snooze, enabled: e.target.checked })}
            />
          </label>
          {draft.snooze.enabled && (
            <>
              <label className="row">
                <span>Snooze length</span>
                <select
                  value={draft.snooze.minutes}
                  onChange={(e) => set('snooze', { ...draft.snooze, minutes: Number(e.target.value) })}
                >
                  {[1, 3, 5, 10, 15, 20, 30].map((n) => (
                    <option key={n} value={n}>
                      {n} min
                    </option>
                  ))}
                </select>
              </label>
              <label className="row">
                <span>Max snoozes</span>
                <select
                  value={draft.snooze.maxCount}
                  onChange={(e) => set('snooze', { ...draft.snooze, maxCount: Number(e.target.value) })}
                >
                  {[1, 2, 3, 5, 10, 0].map((n) => (
                    <option key={n} value={n}>
                      {n === 0 ? 'Unlimited' : n}
                    </option>
                  ))}
                </select>
              </label>
            </>
          )}
        </div>

        <h3 className="section-title">Wake-up check</h3>
        <div className="group">
          <label className="row">
            <span>Check I'm still awake</span>
            <input
              type="checkbox"
              checked={draft.wakeUpCheck.enabled}
              onChange={(e) => set('wakeUpCheck', { ...draft.wakeUpCheck, enabled: e.target.checked })}
            />
          </label>
          {draft.wakeUpCheck.enabled && (
            <label className="row">
              <span>Ask after</span>
              <select
                value={draft.wakeUpCheck.afterMinutes}
                onChange={(e) => set('wakeUpCheck', { ...draft.wakeUpCheck, afterMinutes: Number(e.target.value) })}
              >
                {[3, 5, 10, 15].map((n) => (
                  <option key={n} value={n}>
                    {n} min
                  </option>
                ))}
              </select>
            </label>
          )}
        </div>
        <p className="muted small pad">If you don't answer within a minute, the baby starts crying again.</p>

        {!isNew && onDelete && (
          <button type="button" className="danger-btn" onClick={() => close(onDelete)}>
            Delete Alarm
          </button>
        )}
      </div>
    </div>
  );
}
