import { useEffect, useState } from "react";
import type { BabyPlayer } from "../audio";
import { VOICES } from "../sounds";
import type { SoundId, VoiceChoice } from "../types";

interface Props {
  value: VoiceChoice;
  onChange: (v: VoiceChoice) => void;
  player: BabyPlayer;
  volume: number;
}

const PREVIEW_SECONDS = 6;

export function VoicePicker({ value, onChange, player, volume }: Props) {
  const [previewing, setPreviewing] = useState<SoundId | null>(null);

  useEffect(() => {
    if (!previewing) return;
    const t = window.setTimeout(() => setPreviewing(null), PREVIEW_SECONDS * 1000);
    return () => window.clearTimeout(t);
  }, [previewing]);

  useEffect(() => () => player.stop(), [player]);

  const preview = async (id: SoundId) => {
    if (previewing === id) {
      player.stop();
      setPreviewing(null);
      return;
    }
    await player.unlock();
    setPreviewing(id);
    void player.play(id, { volume, rampSeconds: 0, limitSeconds: PREVIEW_SECONDS });
  };

  return (
    <div className="voices" role="radiogroup" aria-label="Baby voice">
      {VOICES.map((v) => (
        <div
          key={v.id}
          className={`voice ${value === v.id ? "selected" : ""}`}
          role="radio"
          aria-checked={value === v.id}
          tabIndex={0}
          onClick={() => onChange(v.id)}
          onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && onChange(v.id)}
        >
          <span className="voice-emoji" aria-hidden>
            {v.emoji}
          </span>
          <span className="voice-text">
            <span className="voice-name">{v.name}</span>
            <span className="voice-blurb">{v.blurb}</span>
          </span>
          <button
            type="button"
            className={`play ${previewing === v.id ? "on" : ""}`}
            aria-label={previewing === v.id ? `Stop ${v.name}` : `Preview ${v.name}`}
            onClick={(e) => {
              e.stopPropagation();
              void preview(v.id);
            }}
          >
            {previewing === v.id ? "■" : "▶"}
          </button>
        </div>
      ))}
      <div
        className={`voice ${value === "shuffle" ? "selected" : ""}`}
        role="radio"
        aria-checked={value === "shuffle"}
        tabIndex={0}
        onClick={() => onChange("shuffle")}
        onKeyDown={(e) => (e.key === "Enter" || e.key === " ") && onChange("shuffle")}
      >
        <span className="voice-emoji" aria-hidden>
          🎲
        </span>
        <span className="voice-text">
          <span className="voice-name">Surprise baby</span>
          <span className="voice-blurb">A different baby every time, so you never get used to it.</span>
        </span>
      </div>
    </div>
  );
}
