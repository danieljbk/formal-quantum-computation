import { useEffect, useState } from 'react';
import { memoryBoard, memoryMatches, subSeed } from '../core/missions';
import type { MissionProps } from './types';

const SHOW_MS = 2500;

export function MemoryMission({ config, seed, onDone, onActivity }: MissionProps) {
  const [round, setRound] = useState(0);
  const [attempt, setAttempt] = useState(0);
  const [showing, setShowing] = useState(true);
  const [picked, setPicked] = useState<number[]>([]);
  const board = memoryBoard(subSeed(seed, 2, round * 31 + attempt), config.difficulty);

  useEffect(() => {
    setShowing(true);
    setPicked([]);
    const t = setTimeout(() => setShowing(false), SHOW_MS);
    return () => clearTimeout(t);
  }, [round, attempt]);

  const tap = (cell: number) => {
    if (showing) return;
    onActivity();
    const next = picked.includes(cell) ? picked.filter((c) => c !== cell) : [...picked, cell];
    setPicked(next);
    if (next.length === board.lit.length) {
      if (memoryMatches(board, next)) {
        if (round + 1 >= config.rounds) onDone();
        else setRound(round + 1);
      } else {
        setAttempt(attempt + 1);
      }
    }
  };

  return (
    <div className="mission">
      <p className="mission-progress">
        Board {round + 1} of {config.rounds} · {showing ? 'Memorise the toys…' : `Pick ${board.lit.length} tiles`}
      </p>
      <div className="grid" style={{ gridTemplateColumns: `repeat(${board.size}, 1fr)` }}>
        {Array.from({ length: board.size * board.size }, (_, i) => {
          const on = showing ? board.lit.includes(i) : picked.includes(i);
          return (
            <button key={i} aria-label={`tile ${i + 1}`} className={`tile ${on ? 'on' : ''}`} onClick={() => tap(i)}>
              {on ? '🧸' : ''}
            </button>
          );
        })}
      </div>
    </div>
  );
}
