import { useState } from 'react';
import { audioEngine } from '../audio/engine';
import { VOICES } from '../audio/voices';
import type { Action } from '../core/store';
import type { AppState } from '../core/types';
import { VoicePickerView } from './VoicePickerView';

export function SettingsView({ state, dispatch }: { state: AppState; dispatch: (a: Action) => void }) {
  const [audioOk, setAudioOk] = useState(audioEngine.isUnlocked);
  return (
    <section className="view settings">
      <h1>Settings</h1>

      <div className="card">
        <p>
          <strong>Sound check</strong>
        </p>
        <p className="muted">Browsers only play sound after a tap. Keep this page open (screen on) so your alarm can ring.</p>
        <button
          className="primary"
          onClick={async () => {
            setAudioOk(await audioEngine.unlock());
            void audioEngine.previewVoice(state.settings.defaultVoiceId, 2);
          }}
        >
          {audioOk ? 'Sound enabled ✓ — play again' : 'Enable sound'}
        </button>
      </div>

      <label className="card inline">
        <input
          type="checkbox"
          checked={state.settings.use24h}
          onChange={(e) => dispatch({ type: 'UPDATE_SETTINGS', settings: { use24h: e.target.checked } })}
        />{' '}
        24-hour clock
      </label>

      <label className="card field">
        Mission idle timeout (seconds)
        <input
          type="number"
          min={10}
          max={120}
          value={state.settings.missionIdleSeconds}
          onChange={(e) => dispatch({ type: 'UPDATE_SETTINGS', settings: { missionIdleSeconds: Math.min(120, Math.max(10, Number(e.target.value) || 25)) } })}
        />
      </label>

      <fieldset className="card field">
        <legend>Default baby voice for new alarms</legend>
        <VoicePickerView value={state.settings.defaultVoiceId} onChange={(id) => dispatch({ type: 'UPDATE_SETTINGS', settings: { defaultVoiceId: id } })} />
      </fieldset>

      <div className="card credits">
        <p>
          <strong>Sound credits</strong>
        </p>
        <p className="muted">Every cry is a real recording, downloaded from its public source. MP3 copies of non-MP3 originals are format conversions only.</p>
        <ul>
          {VOICES.map((v) => (
            <li key={v.id}>
              <strong>{v.name}</strong> — {v.author}, {v.license}.{' '}
              <a href={v.pageUrl} target="_blank" rel="noreferrer">
                Source
              </a>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
