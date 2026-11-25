import { useEffect, useRef, useState } from 'react';
import { isShake, rockTarget } from '../core/missions';
import type { MissionProps } from './types';

type DME = DeviceMotionEvent & { constructor: { requestPermission?: () => Promise<string> } };

export function RockMission({ config, onDone, onActivity }: MissionProps) {
  const target = rockTarget(config.difficulty) * config.rounds;
  const [count, setCount] = useState(0);
  const [sensor, setSensor] = useState<'unknown' | 'on' | 'off'>('unknown');
  const last = useRef({ x: 0, y: 0, z: 0 });
  const lastAt = useRef(0);
  const done = useRef(false);

  const bump = () => {
    onActivity();
    setCount((c) => c + 1);
  };

  useEffect(() => {
    if (count >= target && !done.current) {
      done.current = true;
      onDone();
    }
  }, [count, target, onDone]);

  useEffect(() => {
    if (sensor !== 'on') return;
    const handler = (e: DeviceMotionEvent) => {
      const a = e.accelerationIncludingGravity;
      if (!a || a.x === null || a.y === null || a.z === null) return;
      const cur = { x: a.x, y: a.y, z: a.z };
      const now = Date.now();
      if (isShake(last.current, cur) && now - lastAt.current > 120) {
        lastAt.current = now;
        bump();
      }
      last.current = cur;
    };
    window.addEventListener('devicemotion', handler);
    return () => window.removeEventListener('devicemotion', handler);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [sensor]);

  const enableSensor = async () => {
    onActivity();
    const Ctor = (typeof DeviceMotionEvent !== 'undefined' ? DeviceMotionEvent : undefined) as unknown as DME['constructor'] | undefined;
    if (!Ctor) return setSensor('off');
    try {
      if (typeof Ctor.requestPermission === 'function') {
        setSensor((await Ctor.requestPermission()) === 'granted' ? 'on' : 'off');
      } else setSensor('on');
    } catch {
      setSensor('off');
    }
  };

  const pct = Math.min(100, Math.round((count / target) * 100));
  return (
    <div className="mission">
      <p className="mission-progress">Rocks: {count} / {target}</p>
      <div className="cradle" style={{ transform: `rotate(${count % 2 ? 12 : -12}deg)` }} aria-hidden>🛏️</div>
      <div className="bar"><div className="bar-fill" style={{ width: `${pct}%` }} /></div>
      {sensor === 'unknown' && <button onClick={enableSensor}>Use motion sensor (shake phone)</button>}
      {sensor === 'on' && <p className="hint">Shake your phone to rock the cradle.</p>}
      <button className="primary rock-btn" onClick={bump}>Rock 🫳</button>
    </div>
  );
}
