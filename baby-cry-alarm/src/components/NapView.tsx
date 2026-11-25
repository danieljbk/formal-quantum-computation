import { describeAlarmTime, formatCountdown } from "../schedule";
import { voiceLabel } from "../sounds";
import type { Alarm } from "../types";

export const NAP_MINUTES = [5, 10, 15, 20, 30, 45, 60, 90];

interface Props {
  alarms: Alarm[];
  now: number;
  use24h: boolean;
  bedside: boolean;
  wakeLockSupported: boolean;
  onNap: (minutes: number) => void;
  onCancel: (id: string) => void;
  onToggleBedside: () => void;
}

/** Quick one-off alarms and the overnight bedside mode. */
export function NapView({ alarms, now, use24h, bedside, wakeLockSupported, onNap, onCancel, onToggleBedside }: Props) {
  const naps = alarms
    .filter((a) => a.enabled && a.fireAt !== undefined && a.fireAt > now)
    .sort((x, y) => x.fireAt! - y.fireAt!);

  return (
    <section className="view" aria-label="Nap">
      <div className="group">
        <div className="group-title">Quick nap</div>
        <p className="hint">One tap sets a one-off alarm. The baby cries when the nap is over.</p>
        <div className="nap-grid">
          {NAP_MINUTES.map((m) => (
            <button key={m} type="button" className="nap-btn" onClick={() => onNap(m)}>
              <span className="nap-num">{m}</span>
              <span className="nap-unit">min</span>
            </button>
          ))}
        </div>
      </div>

      <div className="group">
        <div className="group-title">Running naps</div>
        {naps.length === 0 ? (
          <p className="hint">No nap running.</p>
        ) : (
          naps.map((a) => {
            const t = describeAlarmTime(a, use24h);
            return (
              <div className="row nap-row" key={a.id}>
                <span>
                  <strong>
                    {t.time}
                    {t.meridiem && ` ${t.meridiem}`}
                  </strong>{" "}
                  <span className="muted">
                    · {formatCountdown(a.fireAt! - now)} · {voiceLabel(a.voice)}
                  </span>
                </span>
                <button type="button" className="link" onClick={() => onCancel(a.id)} aria-label={`Cancel ${a.label}`}>
                  Cancel
                </button>
              </div>
            );
          })
        )}
      </div>

      <div className="group">
        <div className="row">
          <span className="group-title">Bedside mode</span>
          <button type="button" className={`pill ${bedside ? "on" : ""}`} onClick={onToggleBedside} aria-pressed={bedside}>
            {bedside ? "On" : "Off"}
          </button>
        </div>
        <p className="hint">
          {wakeLockSupported
            ? "Keeps the screen awake so the alarm can ring overnight. Leave this tab open and the phone plugged in."
            : "This browser can't keep the screen awake. Set auto-lock to Never and leave this tab open."}
        </p>
      </div>
    </section>
  );
}
