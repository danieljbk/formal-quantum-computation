import { useEffect, useMemo, useRef, useState } from 'react';
import type { MissionConfig } from '../types';
import {
  MISSION_INFO,
  checkMathAnswer,
  checkMemory,
  checkPhrase,
  clampRounds,
  createRng,
  createShakeDetector,
  generateMathProblem,
  generateMemoryPuzzle,
  generatePhrase,
  shakeTarget,
  tapTarget,
} from '../missions';

interface Props {
  mission: MissionConfig;
  onComplete: () => void;
  onBack: () => void;
}

/** Runs the dismissal mission; the baby keeps crying until it's done. */
export function MissionPanel({ mission, onComplete, onBack }: Props) {
  const rng = useMemo(() => createRng(Date.now() & 0xffffffff), []);
  const total = clampRounds(mission);
  const [round, setRound] = useState(0);

  const advance = () => {
    if (round + 1 >= total) onComplete();
    else setRound((r) => r + 1);
  };

  return (
    <div className="mission">
      <div className="mission-head">
        <button type="button" className="link" onClick={onBack}>
          ‹ Back
        </button>
        <span>
          {MISSION_INFO[mission.kind].emoji} {MISSION_INFO[mission.kind].title}
          {total > 1 && ` · ${round + 1}/${total}`}
        </span>
        <span />
      </div>
      {mission.kind === 'math' && <MathRound key={round} mission={mission} rng={rng} onSolved={advance} />}
      {mission.kind === 'typing' && <TypingRound key={round} mission={mission} rng={rng} onSolved={advance} />}
      {mission.kind === 'memory' && <MemoryRound key={round} mission={mission} rng={rng} onSolved={advance} />}
      {mission.kind === 'shake' && <ShakeRound target={shakeTarget(mission.difficulty)} onSolved={advance} />}
      {mission.kind === 'tap' && <TapRound target={tapTarget(mission.difficulty)} onSolved={advance} />}
    </div>
  );
}

interface RoundProps {
  mission: MissionConfig;
  rng: () => number;
  onSolved: () => void;
}

function MathRound({ mission, rng, onSolved }: RoundProps) {
  const [problem] = useState(() => generateMathProblem(mission.difficulty, rng));
  const [input, setInput] = useState('');
  const [wrong, setWrong] = useState(false);
  const press = (k: string) => {
    setWrong(false);
    if (k === '⌫') setInput((s) => s.slice(0, -1));
    else if (k === '✓') {
      if (checkMathAnswer(problem, input)) onSolved();
      else {
        setWrong(true);
        setInput('');
      }
    } else if (input.length < 6) setInput((s) => s + k);
  };
  return (
    <div className="mission-body">
      <div className="problem">{problem.prompt} =</div>
      <div className={`answer ${wrong ? 'shake-x' : ''}`} aria-live="polite">
        {input || <span className="muted">?</span>}
      </div>
      <div className="keypad">
        {['1', '2', '3', '4', '5', '6', '7', '8', '9', '⌫', '0', '✓'].map((k) => (
          <button type="button" key={k} className={k === '✓' ? 'key ok' : 'key'} onClick={() => press(k)} aria-label={k === '⌫' ? 'Delete' : k === '✓' ? 'Submit' : k}>
            {k}
          </button>
        ))}
      </div>
    </div>
  );
}

function TypingRound({ mission, rng, onSolved }: RoundProps) {
  const [phrase] = useState(() => generatePhrase(mission.difficulty, rng));
  const [input, setInput] = useState('');
  return (
    <form
      className="mission-body"
      onSubmit={(e) => {
        e.preventDefault();
        if (checkPhrase(phrase, input)) onSolved();
      }}
    >
      <p className="phrase">“{phrase}”</p>
      <input
        className="text-input big"
        autoFocus
        autoCapitalize="off"
        autoComplete="off"
        autoCorrect="off"
        spellCheck={false}
        value={input}
        aria-label="Type the phrase"
        onChange={(e) => {
          setInput(e.target.value);
          if (checkPhrase(phrase, e.target.value)) onSolved();
        }}
        onPaste={(e) => e.preventDefault()}
      />
      <p className="muted small">Type it exactly. No pasting.</p>
    </form>
  );
}

function MemoryRound({ mission, rng, onSolved }: RoundProps) {
  const [puzzle, setPuzzle] = useState(() => generateMemoryPuzzle(mission.difficulty, rng));
  const [showing, setShowing] = useState(true);
  const [selected, setSelected] = useState<Set<number>>(new Set());
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    if (!showing) return;
    const t = window.setTimeout(() => setShowing(false), 2000);
    return () => window.clearTimeout(t);
  }, [showing]);

  const pick = (i: number) => {
    if (showing) return;
    if (!puzzle.tiles.includes(i)) {
      setFailed(true);
      window.setTimeout(() => {
        setPuzzle(generateMemoryPuzzle(mission.difficulty, rng));
        setSelected(new Set());
        setFailed(false);
        setShowing(true);
      }, 700);
      return;
    }
    const next = new Set(selected).add(i);
    setSelected(next);
    if (checkMemory(puzzle, next)) onSolved();
  };

  return (
    <div className="mission-body">
      <p>{showing ? 'Remember the lit tiles…' : failed ? 'Wrong tile! New pattern…' : 'Tap the tiles that were lit.'}</p>
      <div className="memory-grid" style={{ gridTemplateColumns: `repeat(${puzzle.gridSize}, 1fr)` }}>
        {Array.from({ length: puzzle.gridSize ** 2 }, (_, i) => {
          const lit = (showing && puzzle.tiles.includes(i)) || selected.has(i);
          return (
            <button
              type="button"
              key={i}
              className={`tile ${lit ? 'lit' : ''} ${failed ? 'bad' : ''}`}
              aria-label={`Tile ${i + 1}`}
              onClick={() => pick(i)}
            />
          );
        })}
      </div>
    </div>
  );
}

type MotionPermission = 'unknown' | 'granted' | 'denied' | 'unsupported';

function ShakeRound({ target, onSolved }: { target: number; onSolved: () => void }) {
  const [count, setCount] = useState(0);
  const [perm, setPerm] = useState<MotionPermission>(() =>
    typeof window !== 'undefined' && 'DeviceMotionEvent' in window ? 'unknown' : 'unsupported',
  );
  const done = useRef(false);

  useEffect(() => {
    if (perm !== 'granted') return;
    const detect = createShakeDetector();
    const onMotion = (e: DeviceMotionEvent) => {
      const a = e.accelerationIncludingGravity;
      if (!a || a.x == null || a.y == null || a.z == null) return;
      if (detect({ x: a.x, y: a.y, z: a.z }, e.timeStamp)) setCount((c) => c + 1);
    };
    window.addEventListener('devicemotion', onMotion);
    return () => window.removeEventListener('devicemotion', onMotion);
  }, [perm]);

  useEffect(() => {
    if (count >= target && !done.current) {
      done.current = true;
      onSolved();
    }
  }, [count, target, onSolved]);

  const enable = async () => {
    const DME = window.DeviceMotionEvent as unknown as { requestPermission?: () => Promise<'granted' | 'denied'> };
    try {
      const res = DME.requestPermission ? await DME.requestPermission() : 'granted';
      setPerm(res);
    } catch {
      setPerm('denied');
    }
  };

  const pct = Math.min(100, Math.round((count / target) * 100));
  return (
    <div className="mission-body">
      <div className={`shake-baby ${count % 2 ? 'tilt' : ''}`} aria-hidden>
        📳
      </div>
      <div className="progress" role="progressbar" aria-valuenow={count} aria-valuemax={target}>
        <div style={{ width: `${pct}%` }} />
      </div>
      <p>
        {count} / {target} shakes
      </p>
      {perm === 'unknown' && (
        <button type="button" className="primary" onClick={enable}>
          Start shaking
        </button>
      )}
      {(perm === 'denied' || perm === 'unsupported') && (
        <>
          <p className="muted small">Motion sensors aren't available here, so tap the button instead.</p>
          <button type="button" className="primary" onClick={() => setCount((c) => c + 1)}>
            Shake! ({target - count} left)
          </button>
        </>
      )}
    </div>
  );
}

function TapRound({ target, onSolved }: { target: number; onSolved: () => void }) {
  const [count, setCount] = useState(0);
  const [pos, setPos] = useState({ x: 50, y: 50 });
  const tap = () => {
    const next = count + 1;
    setCount(next);
    setPos({ x: 15 + Math.random() * 70, y: 15 + Math.random() * 70 });
    if (next >= target) onSolved();
  };
  return (
    <div className="mission-body">
      <p>
        {count} / {target} taps
      </p>
      <div className="tap-arena">
        <button type="button" className="bottle" style={{ left: `${pos.x}%`, top: `${pos.y}%` }} onClick={tap} aria-label="Tap the bottle">
          🍼
        </button>
      </div>
    </div>
  );
}
