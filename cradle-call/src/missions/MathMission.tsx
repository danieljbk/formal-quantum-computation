import { useState } from 'react';
import { mathProblem, subSeed } from '../core/missions';
import type { MissionProps } from './types';

export function MathMission({ config, seed, onDone, onActivity }: MissionProps) {
  const [round, setRound] = useState(0);
  const [value, setValue] = useState('');
  const [wrong, setWrong] = useState(false);
  const problem = mathProblem(subSeed(seed, 0, round), config.difficulty);

  const submit = () => {
    onActivity();
    if (Number(value.trim()) === problem.answer && value.trim() !== '') {
      setValue('');
      setWrong(false);
      if (round + 1 >= config.rounds) onDone();
      else setRound(round + 1);
    } else {
      setWrong(true);
      setValue('');
    }
  };

  return (
    <div className="mission">
      <p className="mission-progress">Problem {round + 1} of {config.rounds}</p>
      <p className="math-problem" aria-label="problem">{problem.text} = ?</p>
      <input
        aria-label="answer"
        className={wrong ? 'shake-input' : ''}
        inputMode="numeric"
        value={value}
        onChange={(e) => {
          onActivity();
          setValue(e.target.value.replace(/[^\d-]/g, ''));
        }}
        onKeyDown={(e) => e.key === 'Enter' && submit()}
        autoFocus
      />
      {wrong && <p className="mission-error">Not quite. The baby is not impressed.</p>}
      <button className="primary" onClick={submit}>Check</button>
    </div>
  );
}
