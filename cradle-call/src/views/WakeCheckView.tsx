import { formatCountdown } from '../core/schedule';
import type { Action } from '../core/store';

/** Pops up a few minutes after dismissal. Ignore it and the baby starts again. */
export function WakeCheckView({ deadline, now, dispatch }: { deadline: number; now: number; dispatch: (a: Action) => void }) {
  return (
    <div className="ringing wake-check" role="alertdialog" aria-label="Wake-up check">
      <p className="ring-baby" aria-hidden>👀</p>
      <h2>Still awake?</h2>
      <p>Confirm within {formatCountdown(deadline - now)} or the crying starts over.</p>
      <button className="primary big" onClick={() => dispatch({ type: 'CONFIRM_AWAKE', now: Date.now() })}>
        I'm up
      </button>
    </div>
  );
}
