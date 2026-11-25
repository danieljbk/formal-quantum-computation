import type { ChallengeKind, ChallengeProps } from "../../lib/types";
import { MathChallenge } from "./MathChallenge";
import { ShakeChallenge } from "./ShakeChallenge";
import { TypingChallenge } from "./TypingChallenge";
import { MemoryChallenge } from "./MemoryChallenge";
import { RockChallenge } from "./RockChallenge";
import { SequenceChallenge } from "./SequenceChallenge";

const COMPONENTS: Record<ChallengeKind, (p: ChallengeProps) => JSX.Element> = {
  math: MathChallenge,
  shake: ShakeChallenge,
  typing: TypingChallenge,
  memory: MemoryChallenge,
  rock: RockChallenge,
  sequence: SequenceChallenge,
};

export function ChallengeHost({ kind, ...props }: ChallengeProps & { kind: ChallengeKind }) {
  const C = COMPONENTS[kind];
  return <C {...props} />;
}
