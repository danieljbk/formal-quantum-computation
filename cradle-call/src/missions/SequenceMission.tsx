import { useState } from 'react';
import { sequenceBoard, sequenceStep, subSeed } from '../core/missions';
import type { MissionProps } from './types';

export function SequenceMission({ config, seed, onDone, onActivity }: MissionProps) {
  const [round, setRound] = useState(0);
  const [expected, setExpected] = useState(1);
  const [miss, setMiss] = useState(false);
  const board = sequenceBoard(subSeed(seed, 4, round), config.difficulty);
  const cols = Math.ceil(Math.sqrt(board.length));

  const tap = (n: number) => {
    onActivity();
    const next = sequenceStep(expected, n);
    setMiss(next === 1 && n !== expected);
    if (next > board.length) {
      setExpected(1);
      if (round + 1 >= config.rounds) onDone();
      else setRound(round + 1);
    } else setExpected(next);
  };

  return (
    <div className="mission">
      <p className="mission-progress">Board {round + 1} of {config.rounds} · tap {expected} next</p>
      <div className="grid" style={{ gridTemplateColumns: `repeat(${cols}, 1fr)` }}>
        {board.map((n) => (
          <button key={n} className={`tile ${n < expected ? 'on' : ''}`} disabled={n < expected} onClick={() => tap(n)}>
            {n}
          </button>
        ))}
      </div>
      {miss && <p className="mission-error">Wrong block — start again from 1.</p>}
    </div>
  );
}
