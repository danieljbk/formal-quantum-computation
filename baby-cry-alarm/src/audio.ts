import { voiceById } from "./sounds";
import type { SoundId } from "./types";

/** Quietest level a ramped alarm starts from, as a fraction of peak volume. */
export const RAMP_FLOOR = 0.08;

/**
 * Volume at `elapsed` seconds into a ring that fades up over `rampSeconds`
 * to `peak`. Linear from RAMP_FLOOR·peak; flat at peak once the ramp is done.
 */
export function rampVolume(elapsed: number, rampSeconds: number, peak: number): number {
  if (rampSeconds <= 0 || elapsed >= rampSeconds) return peak;
  const start = peak * RAMP_FLOOR;
  return start + (peak - start) * Math.max(0, elapsed / rampSeconds);
}

type Ctx = AudioContext;

/**
 * Plays the baby recordings. Uses Web Audio (gain ramps work on iOS, where
 * HTMLMediaElement.volume is read-only) and falls back to <audio> elsewhere.
 * Browsers only allow sound after a user gesture, so call unlock() from a tap.
 */
export class BabyPlayer {
  private ctx: Ctx | null = null;
  private buffers = new Map<SoundId, Promise<AudioBuffer>>();
  private source: AudioBufferSourceNode | null = null;
  private gain: GainNode | null = null;
  private fallback: HTMLAudioElement | null = null;
  private fallbackTimer: number | null = null;
  private stopTimer: number | null = null;
  private token = 0;
  unlocked = false;

  constructor(private readonly baseUrl: string = "./") {}

  private context(): Ctx | null {
    if (this.ctx) return this.ctx;
    const AC: typeof AudioContext | undefined =
      typeof window !== "undefined"
        ? window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext
        : undefined;
    if (!AC) return null;
    this.ctx = new AC();
    return this.ctx;
  }

  url(id: SoundId): string {
    return this.baseUrl + voiceById(id).file;
  }

  /** Must run inside a user gesture. Safe to call repeatedly. */
  async unlock(): Promise<boolean> {
    const ctx = this.context();
    try {
      if (ctx) {
        if (ctx.state !== "running") await ctx.resume();
        // A one-sample silent buffer fully unlocks output on iOS.
        const b = ctx.createBuffer(1, 1, 22050);
        const s = ctx.createBufferSource();
        s.buffer = b;
        s.connect(ctx.destination);
        s.start(0);
        this.unlocked = ctx.state === "running";
      } else {
        this.unlocked = true;
      }
    } catch {
      this.unlocked = false;
    }
    return this.unlocked;
  }

  /** Start fetching and decoding a recording so the first ring isn't delayed. */
  preload(id: SoundId): Promise<AudioBuffer> | null {
    const ctx = this.context();
    if (!ctx) return null;
    let p = this.buffers.get(id);
    if (!p) {
      p = fetch(this.url(id))
        .then((r) => {
          if (!r.ok) throw new Error(`HTTP ${r.status}`);
          return r.arrayBuffer();
        })
        .then((data) => ctx.decodeAudioData(data));
      p.catch(() => this.buffers.delete(id));
      this.buffers.set(id, p);
    }
    return p;
  }

  /**
   * Cry on loop until stop(). `rampSeconds` fades in from quiet.
   * `limitSeconds` stops automatically (used for previews).
   */
  async play(id: SoundId, opts: { volume: number; rampSeconds: number; limitSeconds?: number }): Promise<void> {
    this.stop();
    const token = ++this.token;
    const ctx = this.context();
    if (ctx) {
      try {
        if (ctx.state !== "running") await ctx.resume();
        const buffer = await this.preload(id)!;
        if (token !== this.token) return; // stopped or replaced while loading
        const gain = ctx.createGain();
        const src = ctx.createBufferSource();
        src.buffer = buffer;
        src.loop = true;
        src.connect(gain).connect(ctx.destination);
        const t0 = ctx.currentTime;
        const peak = opts.volume;
        if (opts.rampSeconds > 0) {
          gain.gain.setValueAtTime(peak * RAMP_FLOOR, t0);
          gain.gain.linearRampToValueAtTime(peak, t0 + opts.rampSeconds);
        } else {
          gain.gain.setValueAtTime(peak, t0);
        }
        src.start(t0);
        this.source = src;
        this.gain = gain;
        this.scheduleStop(token, opts.limitSeconds);
        return;
      } catch {
        // fall through to <audio>
      }
    }
    this.playWithElement(id, token, opts);
  }

  private playWithElement(id: SoundId, token: number, opts: { volume: number; rampSeconds: number; limitSeconds?: number }) {
    if (typeof Audio === "undefined") return;
    const el = new Audio(this.url(id));
    el.loop = true;
    el.volume = rampVolume(0, opts.rampSeconds, opts.volume);
    this.fallback = el;
    void el.play().catch(() => undefined);
    const started = Date.now();
    if (opts.rampSeconds > 0) {
      this.fallbackTimer = window.setInterval(() => {
        const v = rampVolume((Date.now() - started) / 1000, opts.rampSeconds, opts.volume);
        el.volume = v;
        if (v >= opts.volume && this.fallbackTimer !== null) {
          window.clearInterval(this.fallbackTimer);
          this.fallbackTimer = null;
        }
      }, 250);
    }
    this.scheduleStop(token, opts.limitSeconds);
  }

  private scheduleStop(token: number, limitSeconds?: number) {
    if (!limitSeconds) return;
    this.stopTimer = window.setTimeout(() => {
      if (token === this.token) this.stop();
    }, limitSeconds * 1000);
  }

  get playing(): boolean {
    return this.source !== null || this.fallback !== null;
  }

  stop(): void {
    this.token++;
    if (this.stopTimer !== null) window.clearTimeout(this.stopTimer);
    this.stopTimer = null;
    if (this.source) {
      try {
        this.source.stop();
      } catch {
        /* already stopped */
      }
      this.source.disconnect();
      this.gain?.disconnect();
    }
    this.source = null;
    this.gain = null;
    if (this.fallbackTimer !== null) window.clearInterval(this.fallbackTimer);
    this.fallbackTimer = null;
    if (this.fallback) {
      this.fallback.pause();
      this.fallback.src = "";
    }
    this.fallback = null;
  }
}
