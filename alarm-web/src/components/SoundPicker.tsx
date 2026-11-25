import type { SoundId } from '../types';
import { BABY_VOICES } from '../sounds';
import type { CryPlayer } from '../audio';
import { useState } from 'react';

interface Props {
  value: SoundId;
  volume: number;
  player: CryPlayer;
  onChange: (id: SoundId) => void;
}

/** Lets the user choose which baby wakes them, with tap-to-preview. */
export function SoundPicker({ value, volume, player, onChange }: Props) {
  const [previewing, setPreviewing] = useState<SoundId | null>(null);

  const toggle = (id: SoundId) => {
    if (previewing === id) {
      player.stop();
      setPreviewing(null);
      return;
    }
    player.play(id, { volume, fadeInSeconds: 0, vibrate: false, loop: false });
    setPreviewing(id);
  };

  return (
    <div className="group" role="radiogroup" aria-label="Baby voice">
      {BABY_VOICES.map((v) => (
        <div key={v.id} className={`row voice ${value === v.id ? 'selected' : ''}`}>
          <button
            type="button"
            className="voice-main"
            role="radio"
            aria-checked={value === v.id}
            onClick={() => onChange(v.id)}
          >
            <span className="voice-check" aria-hidden>{value === v.id ? '✓' : ''}</span>
            <span className="voice-text">
              <span className="voice-name">👶 {v.name}</span>
              <span className="voice-desc">{v.description}</span>
            </span>
          </button>
          <button
            type="button"
            className="icon-btn"
            aria-label={previewing === v.id ? `Stop ${v.name} preview` : `Preview ${v.name}`}
            onClick={() => toggle(v.id)}
          >
            {previewing === v.id ? '■' : '▶'}
          </button>
        </div>
      ))}
    </div>
  );
}
