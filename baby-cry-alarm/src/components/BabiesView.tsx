import type { BabyPlayer } from "../audio";
import type { VoiceChoice } from "../types";
import { Credits } from "./Credits";
import { VoicePicker } from "./VoicePicker";

interface Props {
  player: BabyPlayer;
  defaultVoice: VoiceChoice;
  onDefaultVoice: (v: VoiceChoice) => void;
}

/** The baby library: listen to each one, pick the default, see where it came from. */
export function BabiesView({ player, defaultVoice, onDefaultVoice }: Props) {
  return (
    <section className="view" aria-label="Babies">
      <div className="group">
        <div className="group-title">Default baby</div>
        <p className="hint">New alarms and naps use this baby. Tap ▶ to hear one.</p>
        <VoicePicker value={defaultVoice} onChange={onDefaultVoice} player={player} volume={0.8} />
      </div>
      <h2 className="section-title">Credits & licenses</h2>
      <Credits />
    </section>
  );
}
