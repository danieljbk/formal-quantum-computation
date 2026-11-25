import { useEffect, useRef, useState } from "react";
import type { ChallengeProps } from "../../lib/types";
import { isShake, shakeTarget } from "../../lib/challenges";

type MotionPermission = { requestPermission?: () => Promise<"granted" | "denied"> };

export function ShakeChallenge({ difficulty, onSolved }: ChallengeProps) {
  const target = shakeTarget(difficulty);
  const [count, setCount] = useState(0);
  const [motionState, setMotionState] = useState<"unknown" | "needs-permission" | "listening" | "unavailable">("unknown");
  const lastShake = useRef(0);
  const solved = useRef(false);

  const bump = () =>
    setCount((c) => {
      const n = Math.min(target, c + 1);
      if (n >= target && !solved.current) {
        solved.current = true;
        setTimeout(onSolved, 250);
      }
      return n;
    });

  useEffect(() => {
    if (typeof window === "undefined" || !("DeviceMotionEvent" in window)) {
      setMotionState("unavailable");
      return;
    }
    const DME = window.DeviceMotionEvent as unknown as MotionPermission;
    if (typeof DME.requestPermission === "function") {
      setMotionState("needs-permission");
      return;
    }
    return listen();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  function listen() {
    const handler = (e: DeviceMotionEvent) => {
      const now = Date.now();
      if (isShake(e.acceleration, lastShake.current, now)) {
        lastShake.current = now;
        bump();
      }
    };
    window.addEventListener("devicemotion", handler);
    setMotionState("listening");
    return () => window.removeEventListener("devicemotion", handler);
  }

  const askPermission = async () => {
    const DME = window.DeviceMotionEvent as unknown as MotionPermission;
    try {
      const res = await DME.requestPermission?.();
      if (res === "granted") listen();
      else setMotionState("unavailable");
    } catch {
      setMotionState("unavailable");
    }
  };

  const pct = Math.round((count / target) * 100);
  return (
    <div className="challenge shake">
      <div className="ring-progress" style={{ ["--pct" as string]: `${pct}%` }}>
        <div className="ring-inner">
          <div className="big-count" data-testid="shake-count">{target - count}</div>
          <div className="muted">shakes left</div>
        </div>
      </div>
      {motionState === "needs-permission" && (
        <button className="btn secondary wide" onClick={askPermission}>
          Enable motion sensor
        </button>
      )}
      <p className="muted center">
        {motionState === "listening" ? "Shake your phone hard — or" : "No motion sensor here —"} tap the button rapidly.
      </p>
      <button className="btn primary wide tap-pad" onClick={bump}>
        📳 Shake / Tap
      </button>
    </div>
  );
}
