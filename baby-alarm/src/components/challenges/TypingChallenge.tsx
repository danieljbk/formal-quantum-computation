import { useMemo, useState } from "react";
import type { ChallengeProps } from "../../lib/types";
import { pickPhrase, typingMatches } from "../../lib/challenges";

export function TypingChallenge({ difficulty, onSolved, onFailedAttempt, rng }: ChallengeProps) {
  const phrase = useMemo(() => pickPhrase(difficulty, rng), [difficulty, rng]);
  const [input, setInput] = useState("");
  const [error, setError] = useState(false);

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    if (typingMatches(phrase, input, difficulty)) onSolved();
    else {
      onFailedAttempt();
      setError(true);
    }
  };

  return (
    <form className="challenge typing" onSubmit={submit}>
      <p className="muted">Type exactly{difficulty === "hard" ? " (case & punctuation count)" : ""}:</p>
      <blockquote className="phrase" data-testid="typing-phrase" onCopy={(e) => e.preventDefault()}>
        {phrase}
      </blockquote>
      <textarea
        className={`text-input ${error ? "error" : ""}`}
        value={input}
        autoFocus
        autoCapitalize="off"
        autoCorrect="off"
        spellCheck={false}
        onPaste={(e) => e.preventDefault()}
        onChange={(e) => {
          setInput(e.target.value);
          setError(false);
        }}
        rows={3}
        aria-label="Type the phrase"
      />
      {error && <p className="error-text">Not quite — check every word.</p>}
      <button className="btn primary wide" type="submit" disabled={!input.trim()}>
        Submit
      </button>
    </form>
  );
}
