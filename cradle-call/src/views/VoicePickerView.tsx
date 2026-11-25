import { audioEngine } from '../audio/engine';
import { VOICES } from '../audio/voices';

/** Choose which baby cries for you. Every voice is a real recording, credited in Settings. */
export function VoicePickerView({ value, onChange }: { value: string; onChange: (id: string) => void }) {
  return (
    <div className="voice-picker" role="radiogroup" aria-label="Baby voice">
      {VOICES.map((v) => (
        <div key={v.id} className={`voice ${v.id === value ? 'selected' : ''}`}>
          <button role="radio" aria-checked={v.id === value} className="voice-main" onClick={() => onChange(v.id)}>
            <strong>{v.name}</strong>
            <span>{v.persona}</span>
          </button>
          <button className="chip" aria-label={`preview ${v.name}`} onClick={() => void audioEngine.previewVoice(v.id)}>
            ▶︎
          </button>
        </div>
      ))}
    </div>
  );
}
