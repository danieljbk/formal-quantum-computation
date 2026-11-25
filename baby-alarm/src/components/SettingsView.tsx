import type { ChallengeKind, Settings } from "../lib/types";
import { CHALLENGES, CHALLENGE_KINDS } from "../lib/challenges";
import { SOUNDS } from "../data/sounds";
import { canVibrate } from "../lib/vibration";

interface Props {
  settings: Settings;
  onChange: (s: Settings) => void;
}

export function SettingsView({ settings, onChange }: Props) {
  const set = <K extends keyof Settings>(k: K, v: Settings[K]) => onChange({ ...settings, [k]: v });
  return (
    <section className="screen">
      <header className="screen-header">
        <h1>Settings</h1>
      </header>
      <div className="form-group">
        <label className="form-row">
          <span>Volume</span>
          <input type="range" min={0.1} max={1} step={0.05} value={settings.volume} onChange={(e) => set("volume", Number(e.target.value))} aria-label="Volume" />
        </label>
        <label className="form-row">
          <span>Gradual volume</span>
          <select value={settings.rampSeconds} onChange={(e) => set("rampSeconds", Number(e.target.value))}>
            <option value={0}>Off</option>
            <option value={10}>10 s</option>
            <option value={20}>20 s</option>
            <option value={45}>45 s</option>
            <option value={90}>90 s</option>
          </select>
        </label>
        <label className="form-row">
          <span>24-hour time</span>
          <span className="switch">
            <input type="checkbox" checked={settings.use24h} onChange={(e) => set("use24h", e.target.checked)} />
            <span className="slider" />
          </span>
        </label>
      </div>

      <div className="group-title">Defaults for new alarms</div>
      <div className="form-group">
        <label className="form-row">
          <span>Baby voice</span>
          <select value={settings.defaultSoundId} onChange={(e) => set("defaultSoundId", e.target.value)}>
            {SOUNDS.map((s) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
        </label>
        <label className="form-row">
          <span>Mission</span>
          <select value={settings.defaultChallenge} onChange={(e) => set("defaultChallenge", e.target.value as ChallengeKind)}>
            {CHALLENGE_KINDS.map((k) => (
              <option key={k} value={k}>{CHALLENGES[k].emoji} {CHALLENGES[k].name}</option>
            ))}
          </select>
        </label>
      </div>

      <div className="group-title">How it works</div>
      <div className="note">
        <p>Alarms ring while this page is open: keep the tab in front, turn on Bedside mode and plug in your phone. Browsers can't wake a closed page.</p>
        <p>Vibration {canVibrate() ? "is supported on this device." : "isn't available in this browser (iOS Safari has none), so the screen pulses instead."}</p>
        <p>Your alarms, settings and wake history are saved on this device only.</p>
      </div>

      <div className="group-title">Sound credits</div>
      <ul className="list credits">
        {SOUNDS.map((s) => (
          <li key={s.id} className="list-row">
            <div>
              <div className="row-title">{s.name}</div>
              <div className="muted small">
                “{s.credit.title}” by {s.credit.creator} ·{" "}
                <a href={s.credit.source} target="_blank" rel="noreferrer">Freesound</a> ·{" "}
                <a href={s.credit.licenseUrl} target="_blank" rel="noreferrer">{s.credit.license}</a>
              </div>
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}
