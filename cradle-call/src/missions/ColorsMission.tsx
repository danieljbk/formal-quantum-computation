import { useState } from 'react';
import { colorRound, CRAYONS, subSeed } from '../core/missions';
import type { MissionProps } from './types';

export function ColorsMission({ config, seed, onDone, onActivity }: MissionProps) {
  const [round, setRound] = useState(0);
  const [attempt, setAttempt] = useState(0);
  const r = colorRound(subSeed(seed, 5, round * 97 + attempt), config.difficulty);

  const pick = (name: string) => {
    onActivity();
    if (name === r.inkName) {
      if (round + 1 >= config.rounds) onDone();
      else setRound(round + 1);
    } else {
      // A wrong pick resets this mission's progress.
      setRound(0);
      setAttempt(attempt + 1);
    }
  };

  return (
    <div className="mission">
      <p className="mission-progress">Round {round + 1} of {config.rounds} · tap the colour of the ink</p>
      <p className="stroop" style={{ color: r.ink }} aria-label="colour word">{r.word}</p>
      <div className="options">
        {r.options.map((name) => (
          <button key={name} onClick={() => pick(name)} style={{ borderColor: CRAYONS.find((c) => c.name === name)?.hex }}>
            {name}
          </button>
        ))}
      </div>
    </div>
  );
}
