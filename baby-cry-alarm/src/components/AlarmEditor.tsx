import { useState } from "react";
import type { BabyPlayer } from "../audio";
import { DAY_SHORT, describeRepeat } from "../schedule";
import type { Alarm, Mission, Weekday } from "../types";
import { Toggle } from "./Toggle";
import { VoicePicker } from "./VoicePicker";

interface Props {
  initial: Alarm;
  isNew: boolean;
  player: BabyPlayer;
  onSave: (a: Alarm) => void;
  onCancel: () => void;
  onDelete: (id: string) => void;
  onTest: (a: Alarm) => void;
}

const ORDER: Weekday[] = [1, 2, 3, 4, 5, 6, 0];
const PRESETS: { label: string; days: Weekday[] }[] = [
  { label: "Once", days: [] },
  { label: "Weekdays", days: [1, 2, 3, 4, 5] },
  { label: "Weekends", days: [0, 6] },
  { label: "Every day", days: [0, 1, 2, 3, 4, 5, 6] },
];
const RAMPS = [0, 15, 30, 60];
const MISSION_KINDS: { kind: Mission["kind"]; label: string; icon: string }[] = [
  { kind: "none", label: "None", icon: "😴" },
  { kind: "math", label: "Math", icon: "🧮" },
  { kind: "typing", label: "Type", icon: "⌨️" },
  { kind: "rock", label: "Rock", icon: "🤱" },
];

function defaultMission(kind: Mission["kind"]): Mission {
  switch (kind) {
    case "none":
      return { kind: "none" };
    case "math":
      return { kind: "math", difficulty: 1, rounds: 3 };
    case "typing":
      return { kind: "typing", rounds: 1 };
    case "rock":
      return { kind: "rock", rocks: 20 };
  }
}

const pad = (n: number) => String(n).padStart(2, "0");

export function AlarmEditor({ initial, isNew, player, onSave, onCancel, onDelete, onTest }: Props) {
  const [a, setA] = useState<Alarm>(initial);
  const set = <K extends keyof Alarm>(k: K, v: Alarm[K]) => setA((prev) => ({ ...prev, [k]: v }));
  const isQuick = a.fireAt !== undefined;

  const toggleDay = (d: Weekday) =>
    set("repeat", a.repeat.includes(d) ? a.repeat.filter((x) => x !== d) : [...a.repeat, d]);

  const finish = (): Alarm => {
    const out: Alarm = { ...a, enabled: true, skipUntil: undefined, label: a.label.trim() };
    return out;
  };

  return (
    <div className="sheet" role="dialog" aria-label={isNew ? "New alarm" : "Edit alarm"}>
      <header className="sheet-head">
        <button type="button" className="link" onClick={onCancel}>
          Cancel
        </button>
        <h2>{isNew ? "New alarm" : "Edit alarm"}</h2>
        <button type="button" className="link strong" onClick={() => onSave(finish())}>
          Save
        </button>
      </header>

      <div className="sheet-body">
        {!isQuick && (
          <section className="time-pick">
            <input
              aria-label="Alarm time"
              type="time"
              value={`${pad(a.hour)}:${pad(a.minute)}`}
              onChange={(e) => {
                const [h, m] = e.target.value.split(":").map(Number);
                if (Number.isInteger(h) && Number.isInteger(m)) setA((p) => ({ ...p, hour: h, minute: m }));
              }}
            />
          </section>
        )}

        <section className="group">
          <label className="row">
            <span>Label</span>
            <input
              className="text"
              type="text"
              maxLength={40}
              placeholder="Alarm"
              value={a.label}
              onChange={(e) => set("label", e.target.value)}
            />
          </label>
        </section>

        {!isQuick && (
          <section className="group">
            <div className="group-title">
              Repeat <span className="muted">· {describeRepeat(a.repeat)}</span>
            </div>
            <div className="days">
              {ORDER.map((d) => (
                <button
                  key={d}
                  type="button"
                  className={`day ${a.repeat.includes(d) ? "on" : ""}`}
                  aria-pressed={a.repeat.includes(d)}
                  aria-label={DAY_SHORT[d]}
                  onClick={() => toggleDay(d)}
                >
                  {DAY_SHORT[d][0]}
                </button>
              ))}
            </div>
            <div className="chips">
              {PRESETS.map((p) => (
                <button key={p.label} type="button" className="chip" onClick={() => set("repeat", p.days)}>
                  {p.label}
                </button>
              ))}
            </div>
          </section>
        )}

        <section className="group">
          <div className="group-title">Baby voice</div>
          <VoicePicker value={a.voice} onChange={(v) => set("voice", v)} player={player} volume={a.volume} />
        </section>

        <section className="group">
          <div className="group-title">Wake-up mission</div>
          <p className="hint">The crying only stops when the mission is done.</p>
          <div className="segmented" role="radiogroup" aria-label="Wake-up mission">
            {MISSION_KINDS.map((m) => (
              <button
                key={m.kind}
                type="button"
                role="radio"
                aria-checked={a.mission.kind === m.kind}
                className={a.mission.kind === m.kind ? "on" : ""}
                onClick={() => a.mission.kind !== m.kind && set("mission", defaultMission(m.kind))}
              >
                <span aria-hidden>{m.icon}</span> {m.label}
              </button>
            ))}
          </div>
          {a.mission.kind === "math" && (
            <>
              <label className="row">
                <span>Difficulty</span>
                <select
                  value={a.mission.difficulty}
                  onChange={(e) =>
                    a.mission.kind === "math" &&
                    set("mission", { ...a.mission, difficulty: Number(e.target.value) as 1 | 2 | 3 })
                  }
                >
                  <option value={1}>Easy (23 + 41)</option>
                  <option value={2}>Medium (37 + 58 + 64)</option>
                  <option value={3}>Hard (14 × 7 + 36)</option>
                </select>
              </label>
              <Stepper
                label="Problems"
                value={a.mission.rounds}
                min={1}
                max={10}
                onChange={(n) => a.mission.kind === "math" && set("mission", { ...a.mission, rounds: n })}
              />
            </>
          )}
          {a.mission.kind === "typing" && (
            <Stepper
              label="Phrases"
              value={a.mission.rounds}
              min={1}
              max={5}
              onChange={(n) => a.mission.kind === "typing" && set("mission", { ...a.mission, rounds: n })}
            />
          )}
          {a.mission.kind === "rock" && (
            <Stepper
              label="Rocks (shake or tap)"
              value={a.mission.rocks}
              min={5}
              max={100}
              step={5}
              onChange={(n) => a.mission.kind === "rock" && set("mission", { ...a.mission, rocks: n })}
            />
          )}
        </section>

        <section className="group">
          <div className="group-title">Sound</div>
          <label className="row">
            <span>Volume</span>
            <input
              type="range"
              min={10}
              max={100}
              value={Math.round(a.volume * 100)}
              aria-label="Volume"
              onChange={(e) => set("volume", Number(e.target.value) / 100)}
            />
          </label>
          <label className="row">
            <span>Fade in</span>
            <select value={a.rampSeconds} onChange={(e) => set("rampSeconds", Number(e.target.value))}>
              {RAMPS.map((r) => (
                <option key={r} value={r}>
                  {r === 0 ? "Off, full volume at once" : `Over ${r} seconds`}
                </option>
              ))}
            </select>
          </label>
          <div className="row">
            <span>Vibrate</span>
            <Toggle label="Vibrate" checked={a.vibrate} onChange={(v) => set("vibrate", v)} />
          </div>
        </section>

        <section className="group">
          <div className="row">
            <span>Snooze</span>
            <Toggle label="Snooze" checked={a.snooze.enabled} onChange={(v) => set("snooze", { ...a.snooze, enabled: v })} />
          </div>
          {a.snooze.enabled && (
            <>
              <Stepper
                label="Minutes"
                value={a.snooze.minutes}
                min={1}
                max={30}
                onChange={(n) => set("snooze", { ...a.snooze, minutes: n })}
              />
              <Stepper
                label="Times allowed"
                value={a.snooze.maxCount}
                min={1}
                max={10}
                onChange={(n) => set("snooze", { ...a.snooze, maxCount: n })}
              />
            </>
          )}
        </section>

        <div className="actions">
          <button type="button" className="btn ghost" onClick={() => onTest(finish())}>
            Test this alarm now
          </button>
          {!isNew && (
            <button type="button" className="btn danger" onClick={() => onDelete(a.id)}>
              Delete alarm
            </button>
          )}
        </div>
      </div>
    </div>
  );
}

function Stepper(props: {
  label: string;
  value: number;
  min: number;
  max: number;
  step?: number;
  onChange: (n: number) => void;
}) {
  const { label, value, min, max, step = 1, onChange } = props;
  return (
    <div className="row">
      <span>{label}</span>
      <span className="stepper">
        <button type="button" aria-label={`Fewer ${label}`} disabled={value <= min} onClick={() => onChange(Math.max(min, value - step))}>
          −
        </button>
        <output aria-label={label}>{value}</output>
        <button type="button" aria-label={`More ${label}`} disabled={value >= max} onClick={() => onChange(Math.min(max, value + step))}>
          +
        </button>
      </span>
    </div>
  );
}
