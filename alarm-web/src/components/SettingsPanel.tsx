import type { Settings } from '../types';
import { BABY_VOICES } from '../sounds';

interface Props {
  settings: Settings;
  onChange: (settings: Settings) => void;
}

export function SettingsPanel({ settings, onChange }: Props) {
  return (
    <section className="panel">
      <h2 className="panel-title">Settings</h2>
      <div className="group">
        <label className="row">
          <span>24-hour time</span>
          <input type="checkbox" checked={settings.use24h} onChange={(e) => onChange({ ...settings, use24h: e.target.checked })} />
        </label>
        <label className="row">
          <span>Default baby for new alarms</span>
          <select
            value={settings.defaultSound}
            onChange={(e) => onChange({ ...settings, defaultSound: e.target.value as Settings['defaultSound'] })}
          >
            {BABY_VOICES.map((v) => (
              <option key={v.id} value={v.id}>
                {v.name}
              </option>
            ))}
          </select>
        </label>
      </div>

      <h3 className="section-title">Keep it ringing</h3>
      <p className="muted small pad">
        A web page can only cry while it's open. Before bed, leave Wail open on your bedside and plugged in. Bedside mode
        keeps the screen awake, and adding Wail to your Home Screen gives it a full-screen app window.
      </p>

      <h3 className="section-title">Baby voice credits</h3>
      <ul className="credits">
        {BABY_VOICES.map((v) => (
          <li key={v.id}>
            <strong>{v.name}</strong>: recording by {v.credit}, {v.license}.{' '}
            <a href={v.sourcePage} target="_blank" rel="noreferrer">
              Source
            </a>
          </li>
        ))}
      </ul>
    </section>
  );
}
