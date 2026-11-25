import { useState } from 'react';

interface Props {
  onCreate: (minutes: number) => void;
}

const PRESETS = [1, 5, 10, 15, 20, 30, 45, 60, 90];

/** Nap / quick alarm: ring once N minutes from now. */
export function QuickAlarm({ onCreate }: Props) {
  const [minutes, setMinutes] = useState(20);
  return (
    <section className="panel">
      <h2 className="panel-title">Quick alarm</h2>
      <p className="muted">Power nap? The baby will cry in…</p>
      <div className="quick-display">
        <button type="button" className="round-btn" onClick={() => setMinutes((m) => Math.max(1, m - 1))} aria-label="One minute less">
          −
        </button>
        <span className="quick-minutes">
          {minutes}
          <span className="small"> min</span>
        </span>
        <button type="button" className="round-btn" onClick={() => setMinutes((m) => Math.min(720, m + 1))} aria-label="One minute more">
          +
        </button>
      </div>
      <div className="preset-row">
        {PRESETS.map((p) => (
          <button type="button" key={p} className={`chip-btn ${p === minutes ? 'on' : ''}`} onClick={() => setMinutes(p)}>
            {p >= 60 ? `${p / 60} h` : `${p}m`}
          </button>
        ))}
      </div>
      <button type="button" className="primary wide" onClick={() => onCreate(minutes)}>
        Start {minutes}-minute alarm
      </button>
    </section>
  );
}
