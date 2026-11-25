import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { BabyPlayer } from "./audio";
import { AlarmEditor } from "./components/AlarmEditor";
import { AlarmsView } from "./components/AlarmsView";
import { BabiesView } from "./components/BabiesView";
import { NapView } from "./components/NapView";
import { RingingScreen } from "./components/RingingScreen";
import { SettingsView, type NotifyState } from "./components/SettingsView";
import { TabBar, type Tab } from "./components/TabBar";
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
import { alarmFromSettings, load, save, type Settings } from "./storage";
import type { Alarm, Ringing } from "./types";

const TITLES: Record<Tab, string> = { alarms: "Alarms", nap: "Nap", babies: "Babies", settings: "Settings" };

type WakeLockSentinel = { release: () => Promise<void> };
type WakeLockApi = { request: (t: "screen") => Promise<WakeLockSentinel> };

function safeStorage(): Storage | null {
  try {
    return typeof window !== "undefined" ? window.localStorage : null;
  } catch {
    return null;
  }
}

function notifyState(): NotifyState {
  return typeof Notification === "undefined" ? "unsupported" : (Notification.permission as NotifyState);
}

function wakeLockApi(): WakeLockApi | undefined {
  return typeof navigator !== "undefined" ? (navigator as Navigator & { wakeLock?: WakeLockApi }).wakeLock : undefined;
}

interface Props {
  /** Injected for tests; the real app makes its own. */
  player?: BabyPlayer;
  clockNow?: () => number;
}

export function App({ player: injected, clockNow = Date.now }: Props) {
  const player = useMemo(() => injected ?? new BabyPlayer("./"), [injected]);
  const initial = useMemo(() => load(safeStorage()), []);
  const [clock, setClock] = useState<ClockState>(() => ({
    alarms: initial.alarms,
    snoozes: initial.snoozes,
    ringing: null,
    lastCheck: clockNow(),
  }));
  const [settings, setSettings] = useState<Settings>(initial.settings);
  const [now, setNow] = useState(clockNow);
  const [tab, setTab] = useState<Tab>("alarms");
  const [editing, setEditing] = useState<{ alarm: Alarm; isNew: boolean } | null>(null);
  const [test, setTest] = useState<{ alarm: Alarm; ringing: Ringing } | null>(null);
  const [armed, setArmed] = useState(false);
  const [bedside, setBedside] = useState(false);
  const [notify, setNotify] = useState<NotifyState>(notifyState);
  const wakeLock = useRef<WakeLockSentinel | null>(null);

  // Persist alarms, pending snoozes and settings.
  useEffect(() => {
    save(safeStorage(), { alarms: clock.alarms, snoozes: clock.snoozes, seeded: true, settings });
  }, [clock.alarms, clock.snoozes, settings]);

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
    if (document.visibilityState !== "visible" && notifyState() === "granted") {
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
    setArmed(await player.unlock());
  }, [armed, player]);

  const requestNotify = async () => {
    if (typeof Notification === "undefined") return;
    try {
      setNotify((await Notification.requestPermission()) as NotifyState);
    } catch {
      setNotify(notifyState());
    }
  };

  const toggleBedside = async () => {
    await arm();
    if (bedside) {
      await wakeLock.current?.release().catch(() => undefined);
      wakeLock.current = null;
      setBedside(false);
      return;
    }
    try {
      wakeLock.current = (await wakeLockApi()?.request("screen")) ?? null;
    } catch {
      wakeLock.current = null;
    }
    setBedside(true);
  };

  const addNap = (minutes: number) => {
    const at = Math.floor((clockNow() + minutes * 60_000) / 1000) * 1000;
    const d = new Date(at);
    setClock((s) =>
      upsertAlarm(
        s,
        alarmFromSettings(settings, {
          hour: d.getHours(),
          minute: d.getMinutes(),
          fireAt: at,
          label: `${minutes}-min nap`,
          rampSeconds: 15,
        }),
      ),
    );
    void arm();
  };

  const next = nextRing(clock.alarms, clock.snoozes, now);
  const nowDate = new Date(now);
  const big = formatClock(nowDate.getHours(), nowDate.getMinutes(), settings.use24h);
  const dateLine = nowDate.toLocaleDateString(undefined, { weekday: "long", month: "long", day: "numeric" });
  const snoozeMap = new Map(clock.snoozes.map((s) => [s.alarmId, s.at]));

  return (
    <div className="app" onClick={() => void arm()}>
      <header className="top">
        <div className="brand">
          <span aria-hidden>😭</span> Baby Cry Alarm
        </div>
        <h1 className="tab-title">{TITLES[tab]}</h1>
      </header>

      {tab === "alarms" && (
      <section className="hero">
        <div className="now" aria-label="Current time">
          {big.time}
          {big.meridiem && <span className="meridiem">{big.meridiem}</span>}
        </div>
        <div className="date">{dateLine}</div>
        <div className="next" aria-live="polite">
          {next ? `Next cry ${formatCountdown(next.at - now)}` : "No alarms set. Sleep in peace."}
        </div>
      </section>
      )}

      {!armed && (
        <button type="button" className="arm" onClick={() => void arm()}>
          🔇 Tap to let the baby cry. Browsers keep the sound off until you tap once.
        </button>
      )}

      <main>
        {tab === "alarms" && (
          <AlarmsView
            alarms={clock.alarms}
            now={now}
            use24h={settings.use24h}
            snoozedUntil={snoozeMap}
            onOpen={(a) => setEditing({ alarm: a, isNew: false })}
            onToggle={(a, on) =>
              setClock((s) =>
                on && a.fireAt !== undefined && nextOccurrence({ ...a, enabled: true }, clockNow()) === null
                  ? // A quick alarm already in the past comes back as a one-off at the same clock time.
                    upsertAlarm(s, { ...a, fireAt: undefined, enabled: true })
                  : setEnabled(s, a.id, on),
              )
            }
            onSkip={(a) => setClock((s) => skipNext(s, a.id, clockNow()))}
          />
        )}
        {tab === "nap" && (
          <NapView
            alarms={clock.alarms}
            now={now}
            use24h={settings.use24h}
            bedside={bedside}
            wakeLockSupported={wakeLockApi() !== undefined}
            onNap={addNap}
            onCancel={(id) => setClock((s) => removeAlarm(s, id))}
            onToggleBedside={() => void toggleBedside()}
          />
        )}
        {tab === "babies" && (
          <BabiesView
            player={player}
            defaultVoice={settings.defaultVoice}
            onDefaultVoice={(v) => setSettings((s) => ({ ...s, defaultVoice: v }))}
          />
        )}
        {tab === "settings" && (
          <SettingsView
            settings={settings}
            onChange={setSettings}
            notify={notify}
            onRequestNotify={() => void requestNotify()}
            alarmCount={clock.alarms.length}
            onDeleteAll={() => setClock((s) => ({ ...s, alarms: [], snoozes: [], ringing: null }))}
          />
        )}
      </main>

      {tab === "alarms" && (
        <button
          type="button"
          className="fab"
          aria-label="Add alarm"
          onClick={() => setEditing({ alarm: alarmFromSettings(settings, { hour: 7, minute: 0 }), isNew: true })}
        >
          +
        </button>
      )}

      <TabBar active={tab} onChange={setTab} />

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

      {active && (
        <RingingScreen
          key={ringKey!}
          ringing={active.ringing}
          alarm={active.alarm}
          now={now}
          use24h={settings.use24h}
          snoozesLeft={test ? active.alarm.snooze.maxCount : snoozesLeft(clock)}
          onSnooze={() => (test ? setTest(null) : setClock((s) => snooze(s, clockNow())))}
          onDismiss={() => (test ? setTest(null) : setClock((s) => dismiss(s, clockNow())))}
        />
      )}
    </div>
  );
}
