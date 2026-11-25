import { useMemo, useState } from "react";
import type { ChallengeProps } from "../../lib/types";
import { makeMathProblem, mathRounds } from "../../lib/challenges";

export function MathChallenge({ difficulty, onSolved, onFailedAttempt, rng }: ChallengeProps) {
  const rounds = mathRounds(difficulty);
  const [round, setRound] = useState(0);
  const [input, setInput] = useState("");
  const [shake, setShake] = useState(false);
  const problem = useMemo(() => makeMathProblem(difficulty, rng), [difficulty, rng, round]);

  const submit = () => {
    if (input.trim() !== "" && Number(input) === problem.answer) {
      if (round + 1 >= rounds) onSolved();
      else {
        setRound(round + 1);
        setInput("");
      }
    } else {
      onFailedAttempt();
      setInput("");
      setShake(true);
      setTimeout(() => setShake(false), 400);
    }
  };

  const press = (k: string) => {
    if (k === "⌫") setInput((v) => v.slice(0, -1));
    else if (k === "±") setInput((v) => (v.startsWith("-") ? v.slice(1) : "-" + v));
    else if (input.replace("-", "").length < 6) setInput((v) => v + k);
  };

  return (
    <div className="challenge math">
      <div className="progress-dots" aria-label={`Problem ${round + 1} of ${rounds}`}>
        {Array.from({ length: rounds }, (_, i) => (
          <span key={i} className={i < round ? "dot done" : i === round ? "dot current" : "dot"} />
        ))}
      </div>
      <div className="math-problem" data-testid="math-problem">{problem.text} = ?</div>
      <div className={`math-input ${shake ? "shake-x" : ""}`} data-testid="math-input">
        {input || <span className="placeholder">answer</span>}
      </div>
      <div className="keypad">
        {["1", "2", "3", "4", "5", "6", "7", "8", "9", "±", "0", "⌫"].map((k) => (
          <button key={k} className="key" onClick={() => press(k)} aria-label={k === "⌫" ? "delete" : k}>
            {k}
          </button>
        ))}
      </div>
      <button className="btn primary wide" onClick={submit} disabled={input === "" || input === "-"}>
        Submit
      </button>
    </div>
  );
}
