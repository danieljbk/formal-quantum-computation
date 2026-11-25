import { useEffect, useRef, useState } from "react";
import { SOUND_CATEGORIES, soundsInCategory } from "../data/sounds";
import { PreviewPlayer } from "../lib/audio";

interface Props {
  selectedId: string;
  volume: number;
  onSelect: (id: string) => void;
}

/** Choose which baby wakes you up, with previews grouped by category. */
export function VoicePicker({ selectedId, volume, onSelect }: Props) {
  const player = useRef(new PreviewPlayer());
  const [playing, setPlaying] = useState<string | null>(null);

  useEffect(() => {
    const p = player.current;
    return () => p.stop();
  }, []);

  const preview = (id: string) => setPlaying(player.current.toggle(id, volume, () => setPlaying(null)));

  return (
    <div className="voice-picker">
      {SOUND_CATEGORIES.map((cat) => (
        <div key={cat.id} className="voice-group">
          <div className="group-title">
            {cat.emoji} {cat.name} <span className="muted small">— {cat.blurb}</span>
          </div>
          <ul className="list">
            {soundsInCategory(cat.id).map((s) => (
              <li key={s.id} className={`list-row ${s.id === selectedId ? "selected" : ""}`}>
                <button className="row-main" onClick={() => onSelect(s.id)} aria-pressed={s.id === selectedId}>
                  <span className="check">{s.id === selectedId ? "✓" : ""}</span>
                  <span>
                    <span className="row-title">{s.name}</span>
                    <span className="intensity" aria-label={`intensity ${s.intensity} of 5`}>
                      {"●".repeat(s.intensity)}
                      <span className="faint">{"●".repeat(5 - s.intensity)}</span>
                    </span>
                  </span>
                </button>
                <button className="chip" onClick={() => preview(s.id)} aria-label={`Preview ${s.name}`}>
                  {playing === s.id ? "■ Stop" : "▶︎ Play"}
                </button>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}
