import { useMemo, useState } from "react";
import type { ChallengeProps } from "../../lib/types";
import { makeSequenceBoard, sequenceSize } from "../../lib/challenges";

export function SequenceChallenge({ difficulty, onSolved, onFailedAttempt, rng }: ChallengeProps) {
  const n = sequenceSize(difficulty);
  const [attempt, setAttempt] = useState(0);
  const board = useMemo(() => makeSequenceBoard(n, rng), [n, rng, attempt]);
  const [next, setNext] = useState(1);
  const [wrong, setWrong] = useState<number | null>(null);

  const tap = (v: number) => {
    if (v === next) {
      if (v === n) onSolved();
      else setNext(v + 1);
    } else if (v > next) {
      onFailedAttempt();
      setWrong(v);
      setTimeout(() => {
        setWrong(null);
        setNext(1);
        setAttempt((a) => a + 1);
      }, 500);
    }
  };

  return (
    <div className="challenge sequence">
      <p className="muted center">Tap 1 → {n} in order. A mistake reshuffles the board.</p>
      <div className={`seq-grid cols-${n <= 6 ? 3 : n <= 9 ? 3 : 4}`}>
        {board.map((v) => (
          <button
            key={`${attempt}-${v}`}
            className={`seq-cell ${v < next ? "done" : ""} ${wrong === v ? "wrong" : ""}`}
            onClick={() => tap(v)}
            disabled={v < next}
          >
            {v}
          </button>
        ))}
      </div>
    </div>
  );
}
