import { useEffect, useMemo, useRef, useState } from "react";
import {
  checkMath,
  checkPhrase,
  makeMathProblem,
  makeRng,
  missionSteps,
  pickPhrase,
  RockDetector,
  type MathProblem,
} from "../missions";
import type { Mission } from "../types";

interface Props {
  mission: Exclude<Mission, { kind: "none" }>;
  seed: number;
  onDone: () => void;
}

/** The wake-up task that stands between the user and silence. */
export function MissionPanel({ mission, seed, onDone }: Props) {
  const rng = useMemo(() => makeRng(seed), [seed]);
  const total = missionSteps(mission);
  const [done, setDone] = useState(0);

  useEffect(() => {
    if (done >= total) onDone();
  }, [done, total, onDone]);

  const advance = () => setDone((d) => Math.min(total, d + 1));

  return (
    <div className="mission">
      <div className="progress" role="progressbar" aria-valuemin={0} aria-valuemax={total} aria-valuenow={done}>
        <div className="bar" style={{ width: `${(done / total) * 100}%` }} />
      </div>
      <div className="mission-count">
        {Math.min(done + (done < total ? 1 : 0), total)} / {total}
      </div>
      {mission.kind === "math" && <MathStep key={done} difficulty={mission.difficulty} rng={rng} onSolved={advance} />}
      {mission.kind === "typing" && <TypingStep key={done} rng={rng} onSolved={advance} />}
      {mission.kind === "rock" && <RockStep target={mission.rocks} count={done} onRock={advance} />}
    </div>
  );
}

function MathStep({ difficulty, rng, onSolved }: { difficulty: 1 | 2 | 3; rng: () => number; onSolved: () => void }) {
  const [problem] = useState<MathProblem>(() => makeMathProblem(difficulty, rng));
  const [input, setInput] = useState("");
  const [wrong, setWrong] = useState(false);
  const submit = () => {
    if (checkMath(problem, input)) onSolved();
    else {
      setWrong(true);
      setInput("");
    }
  };
  return (
    <form
      className="mission-step"
      onSubmit={(e) => {
        e.preventDefault();
        submit();
      }}
    >
      <div className="problem" aria-label="Problem">
        {problem.prompt} = ?
      </div>
      <input
        aria-label="Answer"
        className={`answer ${wrong ? "wrong" : ""}`}
        inputMode="numeric"
        autoFocus
        autoComplete="off"
        value={input}
        onChange={(e) => {
          setWrong(false);
          setInput(e.target.value);
        }}
      />
      {wrong && <div className="error">Not quite. The baby is still crying.</div>}
      <button type="submit" className="btn primary">
        Check
      </button>
    </form>
  );
}

function TypingStep({ rng, onSolved }: { rng: () => number; onSolved: () => void }) {
  const [phrase] = useState(() => pickPhrase(rng));
  const [input, setInput] = useState("");
  const [wrong, setWrong] = useState(false);
  return (
    <form
      className="mission-step"
      onSubmit={(e) => {
        e.preventDefault();
        if (checkPhrase(phrase, input)) onSolved();
        else setWrong(true);
      }}
    >
      <div className="phrase" aria-label="Phrase">
        “{phrase}”
      </div>
      <input
        aria-label="Type the phrase"
        className={`answer text-answer ${wrong ? "wrong" : ""}`}
        autoFocus
        autoComplete="off"
        autoCapitalize="none"
        spellCheck={false}
        onPaste={(e) => e.preventDefault()}
        value={input}
        onChange={(e) => {
          setWrong(false);
          setInput(e.target.value);
        }}
      />
      {wrong && <div className="error">Check the spelling and try again.</div>}
      <button type="submit" className="btn primary">
        Done
      </button>
    </form>
  );
}

type MotionPermission = { requestPermission?: () => Promise<"granted" | "denied"> };

function RockStep({ target, count, onRock }: { target: number; count: number; onRock: () => void }) {
  const detector = useRef(new RockDetector());
  const onRockRef = useRef(onRock);
  onRockRef.current = onRock;
  const [motion, setMotion] = useState<"off" | "on" | "denied">("off");

  useEffect(() => {
    if (motion !== "on") return;
    const handler = (e: DeviceMotionEvent) => {
      const a = e.acceleration;
      if (a && a.x !== null && a.y !== null && a.z !== null && detector.current.feed(a.x, a.y, a.z)) onRockRef.current();
    };
    window.addEventListener("devicemotion", handler);
    return () => window.removeEventListener("devicemotion", handler);
  }, [motion]);

  const enableMotion = async () => {
    const DME = (typeof DeviceMotionEvent !== "undefined" ? DeviceMotionEvent : undefined) as unknown as
      | MotionPermission
      | undefined;
    if (!DME) return setMotion("denied");
    try {
      if (DME.requestPermission) {
        const r = await DME.requestPermission();
        setMotion(r === "granted" ? "on" : "denied");
      } else setMotion("on");
    } catch {
      setMotion("denied");
    }
  };

  return (
    <div className="mission-step">
      <p className="phrase">Rock the baby back to calm: shake your phone, or tap the cradle.</p>
      <button type="button" className="cradle" aria-label="Rock the cradle" onClick={onRock}>
        <span className={count % 2 ? "tilt-l" : "tilt-r"}>👶</span>
      </button>
      <div className="muted">{Math.max(0, target - count)} rocks to go</div>
      {motion === "off" && (
        <button type="button" className="btn ghost" onClick={() => void enableMotion()}>
          Use shake instead
        </button>
      )}
      {motion === "denied" && <div className="muted">Motion isn’t available here, so tap the cradle.</div>}
    </div>
  );
}
