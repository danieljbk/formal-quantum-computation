import type { Alarm } from "../types";
import { AlarmCard } from "./AlarmCard";

interface Props {
  alarms: Alarm[];
  now: number;
  snoozedUntil: Map<string, number>;
  use24h: boolean;
  onOpen: (a: Alarm) => void;
  onToggle: (a: Alarm, enabled: boolean) => void;
  onSkip: (a: Alarm) => void;
}

function minuteOfDay(a: Alarm): number {
  if (a.fireAt !== undefined) {
    const d = new Date(a.fireAt);
    return d.getHours() * 60 + d.getMinutes();
  }
  return a.hour * 60 + a.minute;
}

/** The alarm list, earliest time of day first. */
export function AlarmsView({ alarms, now, snoozedUntil, use24h, onOpen, onToggle, onSkip }: Props) {
  const sorted = [...alarms].sort((x, y) => minuteOfDay(x) - minuteOfDay(y));
  return (
    <section className="list" aria-label="Alarms">
      {sorted.length === 0 && <p className="empty">No alarms yet. Tap + to add one.</p>}
      {sorted.map((a) => (
        <AlarmCard
          key={a.id}
          alarm={a}
          now={now}
          use24h={use24h}
          snoozedUntil={snoozedUntil.get(a.id)}
          onOpen={() => onOpen(a)}
          onToggle={(on) => onToggle(a, on)}
          onSkip={() => onSkip(a)}
        />
      ))}
    </section>
  );
}
