import { useState } from 'react';
import { subSeed, typingMatches, typingPhrase } from '../core/missions';
import type { MissionProps } from './types';

export function TypingMission({ config, seed, onDone, onActivity }: MissionProps) {
  const [round, setRound] = useState(0);
  const [value, setValue] = useState('');
  const phrase = typingPhrase(subSeed(seed, 1, round), config.difficulty);

  const submit = () => {
    onActivity();
    if (!typingMatches(phrase, value)) return;
    setValue('');
    if (round + 1 >= config.rounds) onDone();
    else setRound(round + 1);
  };

  return (
    <div className="mission">
      <p className="mission-progress">Phrase {round + 1} of {config.rounds}</p>
      {/* Rendered as text with copy disabled so the phrase has to be typed. */}
      <p className="typing-target" onCopy={(e) => e.preventDefault()} aria-label="phrase">{phrase}</p>
      <textarea
        aria-label="typed phrase"
        value={value}
        onPaste={(e) => e.preventDefault()}
        onChange={(e) => {
          onActivity();
          setValue(e.target.value);
        }}
        rows={3}
        autoFocus
        autoCapitalize="off"
        autoCorrect="off"
        spellCheck={false}
      />
      <button className="primary" disabled={!typingMatches(phrase, value)} onClick={submit}>Promise made</button>
    </div>
  );
}
