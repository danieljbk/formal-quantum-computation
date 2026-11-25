import { useState } from "react";
import type { Alarm, ChallengeKind, Difficulty, Settings, VibrationPatternId, Weekday } from "../lib/types";
import { CHALLENGES, CHALLENGE_KINDS } from "../lib/challenges";
import { VIBRATION_PATTERNS } from "../lib/vibration";
import { WEEKDAY_SHORT } from "../lib/scheduler";
import { VoicePicker } from "./VoicePicker";
import { soundById } from "../data/sounds";

interface Props {
  initial: Alarm;
  isNew: boolean;
  settings: Settings;
  onSave: (a: Alarm) => void;
  onDelete: (id: string) => void;
  onCancel: () => void;
}

export function AlarmEditor({ initial, isNew, settings, onSave, onDelete, onCancel }: Props) {
  const [a, setA] = useState<Alarm>(initial);
  const [pickingVoice, setPickingVoice] = useState(false);
  const set = <K extends keyof Alarm>(k: K, v: Alarm[K]) => setA((prev) => ({ ...prev, [k]: v }));
  const timeValue = `${String(a.hour).padStart(2, "0")}:${String(a.minute).padStart(2, "0")}`;

  const toggleDay = (d: Weekday) =>
    set("repeat", a.repeat.includes(d) ? a.repeat.filter((x) => x !== d) : [...a.repeat, d].sort() as Weekday[]);

  if (pickingVoice) {
    return (
      <section className="screen sheet">
        <header className="screen-header">
          <button className="link" onClick={() => setPickingVoice(false)}>‹ Back</button>
          <h2>Baby voice</h2>
          <span />
        </header>
        <VoicePicker selectedId={a.soundId} volume={settings.volume} onSelect={(id) => set("soundId", id)} />
      </section>
    );
  }

  return (
    <section className="screen sheet">
      <header className="screen-header">
        <button className="link" onClick={onCancel}>Cancel</button>
        <h2>{isNew ? "Add Alarm" : "Edit Alarm"}</h2>
        <button className="link strong" onClick={() => onSave(a)}>Save</button>
      </header>

      <input
        className="time-picker"
        type="time"
        value={timeValue}
        aria-label="Alarm time"
        onChange={(e) => {
          const [h, m] = e.target.value.split(":").map(Number);
          if (Number.isFinite(h) && Number.isFinite(m)) setA((p) => ({ ...p, hour: h, minute: m }));
        }}
      />

      <div className="form-group">
        <label className="form-row">
          <span>Label</span>
          <input className="inline-input" value={a.label} maxLength={40} onChange={(e) => set("label", e.target.value)} />
        </label>
        <div className="form-row">
          <span>Repeat</span>
          <div className="days">
            {WEEKDAY_SHORT.map((d, i) => (
              <button
                key={i}
                className={`day ${a.repeat.includes(i as Weekday) ? "on" : ""}`}
                onClick={() => toggleDay(i as Weekday)}
                aria-pressed={a.repeat.includes(i as Weekday)}
                aria-label={["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][i]}
              >
                {d}
              </button>
            ))}
          </div>
        </div>
        <button className="form-row nav" onClick={() => setPickingVoice(true)}>
          <span>Baby voice</span>
          <span className="value">{soundById(a.soundId).name} ›</span>
        </button>
      </div>

      <div className="group-title">Wake-up mission</div>
      <div className="mission-grid">
        {CHALLENGE_KINDS.map((k: ChallengeKind) => (
          <button key={k} className={`mission-tile ${a.challenge === k ? "on" : ""}`} onClick={() => set("challenge", k)} aria-pressed={a.challenge === k}>
            <span className="mission-emoji">{CHALLENGES[k].emoji}</span>
            <span>{CHALLENGES[k].name}</span>
          </button>
        ))}
      </div>
      <p className="muted small pad">{CHALLENGES[a.challenge].description}</p>
      <div className="segmented" role="radiogroup" aria-label="Difficulty">
        {(["easy", "medium", "hard"] as Difficulty[]).map((d) => (
          <button key={d} role="radio" aria-checked={a.difficulty === d} className={a.difficulty === d ? "on" : ""} onClick={() => set("difficulty", d)}>
            {d[0].toUpperCase() + d.slice(1)}
          </button>
        ))}
      </div>

      <div className="form-group">
        <label className="form-row">
          <span>Vibration</span>
          <select value={a.vibration} onChange={(e) => set("vibration", e.target.value as VibrationPatternId)}>
            {(Object.keys(VIBRATION_PATTERNS) as VibrationPatternId[]).map((v) => (
              <option key={v} value={v}>{VIBRATION_PATTERNS[v].name}</option>
            ))}
          </select>
        </label>
        <label className="form-row">
          <span>Snooze length</span>
          <select value={a.snoozeMinutes} onChange={(e) => set("snoozeMinutes", Number(e.target.value))}>
            {[1, 3, 5, 9, 10, 15].map((m) => (
              <option key={m} value={m}>{m} min</option>
            ))}
          </select>
        </label>
        <label className="form-row">
          <span>Snoozes allowed</span>
          <select value={a.maxSnoozes} onChange={(e) => set("maxSnoozes", Number(e.target.value))}>
            {[0, 1, 2, 3, 5].map((m) => (
              <option key={m} value={m}>{m === 0 ? "None" : m}</option>
            ))}
          </select>
        </label>
      </div>

      {!isNew && (
        <button className="btn danger wide" onClick={() => onDelete(a.id)}>
          Delete Alarm
        </button>
      )}
    </section>
  );
}
