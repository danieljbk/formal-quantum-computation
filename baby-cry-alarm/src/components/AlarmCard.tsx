import { describeMission } from "../missions";
import { describeAlarmTime, describeRepeat, formatCountdown, nextOccurrence } from "../schedule";
import { voiceLabel } from "../sounds";
import type { Alarm } from "../types";
import { Toggle } from "./Toggle";

interface Props {
  alarm: Alarm;
  now: number;
  snoozedUntil?: number;
  use24h: boolean;
  onOpen: () => void;
  onToggle: (enabled: boolean) => void;
  onSkip: () => void;
}

export function AlarmCard({ alarm, now, snoozedUntil, use24h, onOpen, onToggle, onSkip }: Props) {
  const t = describeAlarmTime(alarm, use24h);
  const spoken = `${t.time}${t.meridiem ? ` ${t.meridiem}` : ""}`;
  const next = nextOccurrence(alarm, now);
  const skipping = alarm.skipUntil !== undefined && alarm.enabled;
  const when =
    alarm.fireAt !== undefined ? "Quick alarm" : describeRepeat(alarm.repeat);

  return (
    <article
      className={`card ${alarm.enabled ? "" : "off"}`}
      aria-label={`Alarm ${spoken}${alarm.label ? `, ${alarm.label}` : ""}`}
      onClick={onOpen}
    >
      <div className="card-main">
        <div className="card-time">
          {t.time}
          {t.meridiem && <span className="meridiem">{t.meridiem}</span>}
        </div>
        <div className="card-meta">
          <span>{alarm.label || "Alarm"}</span>
          <span className="dot">·</span>
          <span>{when}</span>
        </div>
        <div className="card-meta small">
          <span>🍼 {voiceLabel(alarm.voice)}</span>
          {alarm.mission.kind !== "none" && (
            <>
              <span className="dot">·</span>
              <span>{describeMission(alarm.mission)}</span>
            </>
          )}
        </div>
        {alarm.enabled && (
          <div className="card-next">
            {snoozedUntil !== undefined
              ? `Snoozed · cries again ${formatCountdown(snoozedUntil - now)}`
              : next !== null
                ? `${skipping ? "Skipping one · " : ""}Cries ${formatCountdown(next - now)}`
                : ""}
          </div>
        )}
      </div>
      <div className="card-side">
        <Toggle label={`Alarm ${spoken} on`} checked={alarm.enabled} onChange={onToggle} />
        {alarm.enabled && alarm.repeat.length > 0 && alarm.fireAt === undefined && !skipping && (
          <button
            type="button"
            className="link small"
            onClick={(e) => {
              e.stopPropagation();
              onSkip();
            }}
          >
            Skip next
          </button>
        )}
      </div>
    </article>
  );
}
