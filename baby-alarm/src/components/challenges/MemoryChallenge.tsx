import { useEffect, useMemo, useState } from "react";
import type { ChallengeProps } from "../../lib/types";
import { MEMORY_GRID, checkMemoryInput, makeMemoryPattern, memoryLength } from "../../lib/challenges";

export function MemoryChallenge({ difficulty, onSolved, onFailedAttempt, rng }: ChallengeProps) {
  const [attempt, setAttempt] = useState(0);
  const pattern = useMemo(() => makeMemoryPattern(memoryLength(difficulty), rng), [difficulty, rng, attempt]);
  const [showing, setShowing] = useState(true);
  const [lit, setLit] = useState<number | null>(null);
  const [input, setInput] = useState<number[]>([]);
  const [flashWrong, setFlashWrong] = useState(false);

  useEffect(() => {
    setShowing(true);
    setInput([]);
    const timers: ReturnType<typeof setTimeout>[] = [];
    pattern.forEach((cell, i) => {
      timers.push(setTimeout(() => setLit(cell), 700 + i * 650));
      timers.push(setTimeout(() => setLit(null), 700 + i * 650 + 420));
    });
    timers.push(setTimeout(() => setShowing(false), 700 + pattern.length * 650));
    return () => timers.forEach(clearTimeout);
  }, [pattern]);

  const tap = (cell: number) => {
    if (showing) return;
    const next = [...input, cell];
    const res = checkMemoryInput(pattern, next);
    setLit(cell);
    setTimeout(() => setLit((l) => (l === cell ? null : l)), 180);
    if (res === "wrong") {
      onFailedAttempt();
      setFlashWrong(true);
      setTimeout(() => {
        setFlashWrong(false);
        setAttempt((a) => a + 1);
      }, 600);
    } else if (res === "complete") onSolved();
    else setInput(next);
  };

  return (
    <div className="challenge memory">
      <p className="muted center" data-testid="memory-status">
        {showing ? "Watch the pattern…" : `Repeat it: ${input.length} / ${pattern.length}`}
      </p>
      <div className={`memory-grid ${flashWrong ? "wrong" : ""}`}>
        {Array.from({ length: MEMORY_GRID }, (_, i) => (
          <button
            key={i}
            className={`memory-cell ${lit === i ? "lit" : ""}`}
            onClick={() => tap(i)}
            disabled={showing}
            aria-label={`tile ${i + 1}`}
          />
        ))}
      </div>
    </div>
  );
}
