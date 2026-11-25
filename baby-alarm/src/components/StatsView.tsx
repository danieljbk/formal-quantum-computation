import type { WakeRecord } from "../lib/types";
import { computeStats, formatDuration, secondsToDismiss } from "../lib/analytics";
import { CHALLENGES } from "../lib/challenges";
import { soundById } from "../data/sounds";

interface Props {
  history: WakeRecord[];
  now: Date;
  onClear: () => void;
}

export function StatsView({ history, now, onClear }: Props) {
  const s = computeStats(history, now);
  const max = Math.max(60, ...s.last7Days.map((d) => d.seconds ?? 0));
  const recent = [...history].sort((a, b) => b.dismissedAt - a.dismissedAt).slice(0, 20);

  return (
    <section className="screen">
      <header className="screen-header">
        <h1>Wake Stats</h1>
      </header>
      <div className="stat-grid">
        <Stat label="Streak" value={`${s.streak} ${s.streak === 1 ? "day" : "days"}`} />
        <Stat label="Wake-ups" value={String(s.total)} />
        <Stat label="Avg. to get up" value={s.total ? formatDuration(s.avgSecondsToDismiss) : "—"} />
        <Stat label="No-snooze rate" value={s.total ? `${Math.round(s.noSnoozeRate * 100)}%` : "—"} />
      </div>

      <div className="group-title">Time to soothe · last 7 days</div>
      <div className="chart" role="img" aria-label="Seconds to dismiss per day, last 7 days">
        {s.last7Days.map((d, i) => (
          <div key={i} className="chart-col">
            <div className="chart-bar-wrap">
              {d.seconds !== null && (
                <div className="chart-bar" style={{ height: `${Math.max(4, (d.seconds / max) * 100)}%` }} title={formatDuration(d.seconds)} />
              )}
            </div>
            <div className="chart-label">{d.label}</div>
          </div>
        ))}
      </div>

      <div className="group-title">History</div>
      {recent.length === 0 ? (
        <p className="empty">No wake-ups yet. Ring a test alarm to see it here.</p>
      ) : (
        <ul className="list">
          {recent.map((r) => (
            <li key={r.id} className="list-row history-row">
              <div>
                <div className="row-title">
                  {new Date(r.dismissedAt).toLocaleDateString(undefined, { weekday: "short", month: "short", day: "numeric" })} ·{" "}
                  {new Date(r.firedAt).toLocaleTimeString(undefined, { hour: "numeric", minute: "2-digit" })}
                </div>
                <div className="muted small">
                  {r.alarmLabel} · {soundById(r.soundId).name} · {CHALLENGES[r.challenge]?.emoji} {r.snoozes} snooze{r.snoozes === 1 ? "" : "s"}
                  {r.failedAttempts ? ` · ${r.failedAttempts} miss${r.failedAttempts === 1 ? "" : "es"}` : ""}
                </div>
              </div>
              <div className="value">{formatDuration(secondsToDismiss(r))}</div>
            </li>
          ))}
        </ul>
      )}
      {history.length > 0 && (
        <button className="btn ghost wide" onClick={onClear}>
          Clear history
        </button>
      )}
    </section>
  );
}

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div className="stat">
      <div className="stat-value">{value}</div>
      <div className="stat-label">{label}</div>
    </div>
  );
}
