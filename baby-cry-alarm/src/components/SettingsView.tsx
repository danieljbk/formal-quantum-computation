import type { Settings } from "../storage";
import type { Mission } from "../types";
import { Toggle } from "./Toggle";

export type NotifyState = "unsupported" | "default" | "granted" | "denied";

interface Props {
  settings: Settings;
  onChange: (s: Settings) => void;
  notify: NotifyState;
  onRequestNotify: () => void;
  alarmCount: number;
  onDeleteAll: () => void;
}

const MISSIONS: { kind: Mission["kind"]; label: string }[] = [
  { kind: "none", label: "None" },
  { kind: "math", label: "Math" },
  { kind: "typing", label: "Type a phrase" },
  { kind: "rock", label: "Rock the baby" },
];

const NOTIFY_TEXT: Record<NotifyState, string> = {
  unsupported: "This browser doesn't support notifications.",
  default: "Get a notification if an alarm rings while this tab is in the background.",
  granted: "On. You'll be notified if an alarm rings in the background.",
  denied: "Blocked. Allow notifications for this site in your browser settings.",
};

export function SettingsView({ settings, onChange, notify, onRequestNotify, alarmCount, onDeleteAll }: Props) {
  const set = <K extends keyof Settings>(k: K, v: Settings[K]) => onChange({ ...settings, [k]: v });

  return (
    <section className="view" aria-label="Settings">
      <div className="group">
        <div className="row">
          <span>24-hour clock</span>
          <Toggle label="24-hour clock" checked={settings.use24h} onChange={(v) => set("use24h", v)} />
        </div>
      </div>

      <div className="group">
        <div className="group-title">New alarms</div>
        <label className="row">
          <span>Wake-up mission</span>
          <select
            aria-label="Default mission"
            value={settings.defaultMission}
            onChange={(e) => set("defaultMission", e.target.value as Mission["kind"])}
          >
            {MISSIONS.map((m) => (
              <option key={m.kind} value={m.kind}>
                {m.label}
              </option>
            ))}
          </select>
        </label>
        <div className="row">
          <span>Snooze length</span>
          <span className="stepper">
            <button
              type="button"
              aria-label="Shorter snooze"
              disabled={settings.defaultSnoozeMinutes <= 1}
              onClick={() => set("defaultSnoozeMinutes", Math.max(1, settings.defaultSnoozeMinutes - 1))}
            >
              −
            </button>
            <output aria-label="Snooze length">{settings.defaultSnoozeMinutes} min</output>
            <button
              type="button"
              aria-label="Longer snooze"
              disabled={settings.defaultSnoozeMinutes >= 30}
              onClick={() => set("defaultSnoozeMinutes", Math.min(30, settings.defaultSnoozeMinutes + 1))}
            >
              +
            </button>
          </span>
        </div>
        <p className="hint">The default baby is chosen on the Babies tab.</p>
      </div>

      <div className="group">
        <div className="row">
          <span>Background notifications</span>
          {notify === "default" && (
            <button type="button" className="pill" onClick={onRequestNotify}>
              Turn on
            </button>
          )}
        </div>
        <p className="hint">{NOTIFY_TEXT[notify]}</p>
      </div>

      <div className="group">
        <button
          type="button"
          className="btn danger"
          disabled={alarmCount === 0}
          onClick={() => {
            if (typeof window === "undefined" || window.confirm(`Delete all ${alarmCount} alarms?`)) onDeleteAll();
          }}
        >
          Delete all alarms
        </button>
      </div>

      <p className="hint center">Baby Cry Alarm · real recorded babies</p>
    </section>
  );
}
