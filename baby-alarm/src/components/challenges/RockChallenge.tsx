import { useEffect, useRef, useState } from "react";
import type { ChallengeProps } from "../../lib/types";
import { rockSeconds } from "../../lib/challenges";

/** Press and hold the cradle; letting go early resets the soothing timer. */
export function RockChallenge({ difficulty, onSolved, onFailedAttempt }: ChallengeProps) {
  const needed = rockSeconds(difficulty) * 1000;
  const [held, setHeld] = useState(0);
  const [holding, setHolding] = useState(false);
  const startedAt = useRef<number | null>(null);
  const done = useRef(false);

  useEffect(() => {
    if (!holding) return;
    const t = setInterval(() => {
      if (startedAt.current === null) return;
      const ms = Date.now() - startedAt.current;
      setHeld(ms);
      if (ms >= needed && !done.current) {
        done.current = true;
        clearInterval(t);
        onSolved();
      }
    }, 50);
    return () => clearInterval(t);
  }, [holding, needed, onSolved]);

  const start = () => {
    startedAt.current = Date.now();
    setHolding(true);
  };
  const stop = () => {
    if (!holding) return;
    setHolding(false);
    startedAt.current = null;
    if (!done.current) {
      if (held > 300) onFailedAttempt();
      setHeld(0);
    }
  };

  const pct = Math.min(100, Math.round((held / needed) * 100));
  return (
    <div className="challenge rock">
      <p className="muted center">Press and hold the cradle for {needed / 1000}s without letting go.</p>
      <button
        className={`cradle ${holding ? "rocking" : ""}`}
        onPointerDown={start}
        onPointerUp={stop}
        onPointerLeave={stop}
        onPointerCancel={stop}
        onContextMenu={(e) => e.preventDefault()}
        aria-label="Hold to rock the baby"
      >
        <span className="cradle-emoji">{pct >= 100 ? "😴" : holding ? "🍼" : "😭"}</span>
      </button>
      <div className="bar">
        <div className="bar-fill" style={{ width: `${pct}%` }} />
      </div>
      <p className="muted center" data-testid="rock-status">{holding ? "Shhh… keep rocking" : "Hold to soothe"}</p>
    </div>
  );
}
