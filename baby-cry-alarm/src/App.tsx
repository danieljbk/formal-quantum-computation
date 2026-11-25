import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { BabyPlayer } from "./audio";
import { AlarmCard } from "./components/AlarmCard";
import { AlarmEditor } from "./components/AlarmEditor";
import { Credits } from "./components/Credits";
import { RingingScreen } from "./components/RingingScreen";
import {
  dismiss,
  removeAlarm,
  setEnabled,
  skipNext,
  snooze,
  snoozesLeft,
  tick,
  upsertAlarm,
  type ClockState,
} from "./engine";
import { formatClock, formatCountdown, nextOccurrence, nextRing } from "./schedule";
import { resolveVoice } from "./sounds";
import { defaultAlarm, load, save } from "./storage";
import type { Alarm, Ringing } from "./types";

const QUICK_MINUTES = [5, 10, 20, 30];

function safeStorage(): Storage | null {
  try {
    return typeof window !== "undefined" ? window.localStorage : null;
  } catch {
    return null;
  }
}

function sortAlarms(alarms: Alarm[]): Alarm[] {
  const key = (a: Alarm) => {
    if (a.fireAt !== undefined) {
      const d = new Date(a.fireAt);
      return d.getHours() * 60 + d.getMinutes();
    }
    return a.hour * 60 + a.minute;
  };
  return [...alarms].sort((x, y) => key(x) - key(y));
}

interface Props {
  /** Injected for tests; the real app makes its own. */
  player?: BabyPlayer;
  clockNow?: () => number;
}

export function App({ player: injected, clockNow = Date.now }: Props) {
  const player = useMemo(() => injected ?? new BabyPlayer("./"), [injected]);
  const [clock, setClock] = useState<ClockState>(() => {
    const saved = load(safeStorage());
    return { alarms: saved.alarms, snoozes: saved.snoozes, ringing: null, lastCheck: clockNow() };
  });
  const [now, setNow] = useState(clockNow);
  const [editing, setEditing] = useState<{ alarm: Alarm; isNew: boolean } | null>(null);
  const [showCredits, setShowCredits] = useState(false);
  const [test, setTest] = useState<{ alarm: Alarm; ringing: Ringing } | null>(null);
  const [armed, setArmed] = useState(false);
  const [bedside, setBedside] = useState(false);
  const wakeLock = useRef<{ release: () => Promise<void> } | null>(null);

  // Persist alarms and pending snoozes.
  useEffect(() => {
    save(safeStorage(), { alarms: clock.alarms, snoozes: clock.snoozes, seeded: true });
  }, [clock.alarms, clock.snoozes]);

  // The scheduler: once a second, and immediately when the tab comes back.
  useEffect(() => {
    const step = () => {
      const t = clockNow();
      setNow(t);
      setClock((s) => tick(s, t));
    };
    const id = window.setInterval(step, 1000);
    const onVis = () => document.visibilityState === "visible" && step();
    document.addEventListener("visibilitychange", onVis);
    return () => {
      window.clearInterval(id);
      document.removeEventListener("visibilitychange", onVis);
    };
  }, [clockNow]);

  // Preload the babies that are actually scheduled so the first cry is instant.
  useEffect(() => {
    if (!armed) return;
    for (const a of clock.alarms) if (a.enabled && a.voice !== "shuffle") player.preload(a.voice);
  }, [armed, clock.alarms, player]);

  const active = useMemo(() => {
    if (test) return test;
    if (!clock.ringing) return null;
    const alarm = clock.alarms.find((a) => a.id === clock.ringing!.alarmId);
    return alarm ? { alarm, ringing: clock.ringing } : null;
  }, [test, clock.ringing, clock.alarms]);

  const ringKey = active ? `${active.ringing.alarmId}:${active.ringing.firedAt}:${active.ringing.snoozeCount}` : null;

  // Make noise while something is ringing.
  useEffect(() => {
    if (!active) return;
    const { alarm, ringing } = active;
    void player.play(ringing.soundId, { volume: alarm.volume, rampSeconds: alarm.rampSeconds });
    let buzz: number | null = null;
    if (alarm.vibrate && typeof navigator !== "undefined" && "vibrate" in navigator) {
      const pulse = () => navigator.vibrate?.([700, 300, 700]);
      pulse();
      buzz = window.setInterval(pulse, 2000);
    }
    const prevTitle = document.title;
    document.title = `😭 ${alarm.label || "Alarm"}`;
    if (document.visibilityState !== "visible" && typeof Notification !== "undefined" && Notification.permission === "granted") {
      try {
        new Notification(alarm.label || "Alarm", { body: "The baby is crying. Come back to stop it.", tag: "baby-cry-alarm" });
      } catch {
        /* notifications unavailable */
      }
    }
    return () => {
      player.stop();
      if (buzz !== null) window.clearInterval(buzz);
      navigator.vibrate?.(0);
      document.title = prevTitle;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [ringKey, player]);

  const arm = useCallback(async () => {
    if (armed) return;
    const ok = await player.unlock();
    setArmed(ok);
    if (ok && typeof Notification !== "undefined" && Notification.permission === "default") {
      void Notification.requestPermission().catch(() => undefined);
    }
  }, [armed, player]);

  const toggleBedside = async () => {
    await arm();
    if (bedside) {
      await wakeLock.current?.release().catch(() => undefined);
      wakeLock.current = null;
      setBedside(false);
      return;
    }
    const wl = (navigator as Navigator & { wakeLock?: { request: (t: "screen") => Promise<{ release: () => Promise<void> }> } }).wakeLock;
    try {
      wakeLock.current = wl ? await wl.request("screen") : null;
    } catch {
      wakeLock.current = null;
    }
    setBedside(true);
  };

  const next = nextRing(clock.alarms, clock.snoozes, now);
  const nowDate = new Date(now);
  const big = formatClock(nowDate.getHours(), nowDate.getMinutes());
  const dateLine = nowDate.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });

  const addQuick = (minutes: number) => {
    const at = Math.floor((clockNow() + minutes * 60_000) / 1000) * 1000;
    const d = new Date(at);
    setClock((s) =>
      upsertAlarm(
        s,
        defaultAlarm({ hour: d.getHours(), minute: d.getMinutes(), fireAt: at, label: `${minutes}-min nap`, rampSeconds: 15 }),
      ),
    );
    void arm();
  };

  const snoozeMap = new Map(clock.snoozes.map((s) => [s.alarmId, s.at]));

  return (
    <div className="app" onPointerDown={() => void arm()}>
      <header className="top">
        <div className="brand">
          <span aria-hidden>😭</span> Baby Cry Alarm
        </div>
        <div className="top-actions">
          <button type="button" className={`pill ${bedside ? "on" : ""}`} onClick={() => void toggleBedside()}>
            {bedside ? "🌙 Bedside on" : "🌙 Bedside"}
          </button>
          <button type="button" className="pill" onClick={() => setShowCredits(true)}>
            Babies
          </button>
        </div>
      </header>

      <section className="hero">
        <div className="now" aria-label="Current time">
          {big.time}
          <span className="meridiem">{big.meridiem}</span>
        </div>
        <div className="date">{dateLine}</div>
        <div className="next" aria-live="polite">
          {next ? `Next cry ${formatCountdown(next.at - now)}` : "No alarms set. Sleep in peace."}
        </div>
      </section>

      {!armed && (
        <button type="button" className="arm" onClick={() => void arm()}>
          🔇 Tap to let the baby cry. Browsers keep the sound off until you tap once.
        </button>
      )}
      {bedside && <div className="note">Screen stays on. Leave this tab open by the bed, plugged in.</div>}

      <section className="quick" aria-label="Quick nap alarm">
        <span className="quick-title">Nap</span>
        {QUICK_MINUTES.map((m) => (
          <button key={m} type="button" className="chip" onClick={() => addQuick(m)}>
            +{m} min
          </button>
        ))}
      </section>

      <main className="list">
        {clock.alarms.length === 0 && <p className="empty">No alarms yet. Tap + to add one.</p>}
        {sortAlarms(clock.alarms).map((a) => (
          <AlarmCard
            key={a.id}
            alarm={a}
            now={now}
            snoozedUntil={snoozeMap.get(a.id)}
            onOpen={() => setEditing({ alarm: a, isNew: false })}
            onToggle={(on) =>
              setClock((s) =>
                on && a.fireAt !== undefined && nextOccurrence({ ...a, enabled: true }, clockNow()) === null
                  ? // A quick alarm already in the past comes back as a one-off at the same clock time.
                    upsertAlarm(s, { ...a, fireAt: undefined, enabled: true })
                  : setEnabled(s, a.id, on),
              )
            }
            onSkip={() => setClock((s) => skipNext(s, a.id, clockNow()))}
          />
        ))}
      </main>

      <button
        type="button"
        className="fab"
        aria-label="Add alarm"
        onClick={() => setEditing({ alarm: defaultAlarm({ hour: 7, minute: 0 }), isNew: true })}
      >
        +
      </button>

      <footer className="foot">
        Real recorded babies · <button type="button" className="link" onClick={() => setShowCredits(true)}>credits & licenses</button>
      </footer>

      {editing && (
        <AlarmEditor
          initial={editing.alarm}
          isNew={editing.isNew}
          player={player}
          onCancel={() => setEditing(null)}
          onSave={(a) => {
            setClock((s) => upsertAlarm(s, a));
            setEditing(null);
          }}
          onDelete={(id) => {
            setClock((s) => removeAlarm(s, id));
            setEditing(null);
          }}
          onTest={(a) => {
            void arm();
            const t = clockNow();
            setTest({ alarm: a, ringing: { alarmId: a.id, firedAt: t, snoozeCount: 0, soundId: resolveVoice(a.voice, Math.random) } });
          }}
        />
      )}

      {showCredits && <Credits onClose={() => setShowCredits(false)} />}

      {active && (
        <RingingScreen
          key={ringKey!}
          ringing={active.ringing}
          alarm={active.alarm}
          now={now}
          snoozesLeft={test ? active.alarm.snooze.maxCount : snoozesLeft(clock)}
          onSnooze={() => (test ? setTest(null) : setClock((s) => snooze(s, clockNow())))}
          onDismiss={() => (test ? setTest(null) : setClock((s) => dismiss(s, clockNow())))}
        />
      )}
    </div>
  );
}
