import { soundById } from "../data/sounds";

/** Volume at time t (seconds since start) for a linear ramp from 20% to `target`. */
export function rampVolume(t: number, rampSeconds: number, target: number): number {
  if (rampSeconds <= 0) return target;
  const start = Math.min(0.2, target);
  const frac = Math.min(1, Math.max(0, t / rampSeconds));
  return start + (target - start) * frac;
}

export function soundUrl(file: string): string {
  return `${import.meta.env.BASE_URL}sounds/${file}`;
}

/**
 * Loops the chosen baby recording with a gradual volume ramp.
 * Uses a plain <audio> element so it works on iOS Safari once the page
 * has had a user gesture (the "Arm alarms" tap unlocks it).
 */
export class AlarmPlayer {
  private el: HTMLAudioElement | null = null;
  private rampTimer: ReturnType<typeof setInterval> | null = null;

  start(soundId: string, volume: number, rampSeconds: number): void {
    this.stop();
    const sound = soundById(soundId);
    const el = new Audio(soundUrl(sound.file));
    el.loop = true;
    el.volume = rampVolume(0, rampSeconds, volume);
    this.el = el;
    void el.play().catch(() => {
      /* autoplay blocked; the ring screen offers a tap-to-play button */
    });
    const started = Date.now();
    this.rampTimer = setInterval(() => {
      if (!this.el) return;
      this.el.volume = rampVolume((Date.now() - started) / 1000, rampSeconds, volume);
    }, 250);
  }

  resume(): void {
    void this.el?.play().catch(() => {});
  }

  get isPlaying(): boolean {
    return !!this.el && !this.el.paused;
  }

  stop(): void {
    if (this.rampTimer) clearInterval(this.rampTimer);
    this.rampTimer = null;
    if (this.el) {
      this.el.pause();
      this.el.src = "";
    }
    this.el = null;
  }
}

/** One-shot preview used by the voice picker. */
export class PreviewPlayer {
  private el: HTMLAudioElement | null = null;
  playing: string | null = null;

  toggle(soundId: string, volume: number, onEnd: () => void): string | null {
    const wasSame = this.playing === soundId;
    this.stop();
    if (wasSame) return null;
    const el = new Audio(soundUrl(soundById(soundId).file));
    el.volume = volume;
    el.onended = () => {
      this.playing = null;
      onEnd();
    };
    void el.play().catch(() => onEnd());
    this.el = el;
    this.playing = soundId;
    return soundId;
  }

  stop(): void {
    if (this.el) {
      this.el.pause();
      this.el.src = "";
    }
    this.el = null;
    this.playing = null;
  }
}

/** Play a silent buffer inside a user gesture so later programmatic playback is allowed. */
export function unlockAudio(): void {
  try {
    const Ctx = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctx) return;
    const ctx = new Ctx();
    const buf = ctx.createBuffer(1, 1, 22050);
    const src = ctx.createBufferSource();
    src.buffer = buf;
    src.connect(ctx.destination);
    src.start(0);
    void ctx.resume();
  } catch {
    /* ignore */
  }
}
