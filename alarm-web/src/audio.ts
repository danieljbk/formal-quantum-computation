import type { SoundId } from './types';
import { BABY_VOICES, getVoice } from './sounds';

/** Volume at `elapsed` seconds into a linear fade-in toward `target`. */
export function fadeVolume(elapsedSeconds: number, fadeInSeconds: number, target: number): number {
  if (fadeInSeconds <= 0) return target;
  const t = Math.min(1, Math.max(0, elapsedSeconds / fadeInSeconds));
  // Start at 10% of the target so the first seconds are audible at all.
  return target * (0.1 + 0.9 * t);
}

export function soundUrl(id: SoundId): string {
  return `${import.meta.env?.BASE_URL ?? './'}${getVoice(id).file}`;
}

/**
 * Loops a baby recording with a gradual volume ramp and (where supported) vibration.
 * One instance is shared by the ringing screen and previews.
 */
export class CryPlayer {
  private audio: HTMLAudioElement | null = null;
  private fadeTimer: number | undefined;
  private vibrateTimer: number | undefined;
  private unlocked = false;
  /** Bumped on every real playback so a stale unlock can't pause or mute it. */
  private generation = 0;

  /** iOS only allows audio after a user gesture: call this from a tap to unlock playback. */
  unlock(): void {
    if (this.unlocked) return;
    this.unlocked = true;
    const a = this.ensure();
    const token = ++this.generation;
    a.src = soundUrl(BABY_VOICES[0].id);
    a.muted = true;
    const restore = () => {
      // Only undo the silent unlock if no real playback has started since.
      if (token !== this.generation) return;
      a.pause();
      a.muted = false;
    };
    a.play().then(restore, restore);
  }

  play(sound: SoundId, opts: { volume: number; fadeInSeconds: number; vibrate: boolean; loop?: boolean }): void {
    this.stop();
    this.generation++;
    const a = this.ensure();
    a.muted = false;
    a.src = soundUrl(sound);
    a.loop = opts.loop ?? true;
    a.volume = fadeVolume(0, opts.fadeInSeconds, opts.volume);
    void a.play().catch(() => undefined);
    const started = performance.now();
    if (opts.fadeInSeconds > 0) {
      this.fadeTimer = window.setInterval(() => {
        const elapsed = (performance.now() - started) / 1000;
        a.volume = fadeVolume(elapsed, opts.fadeInSeconds, opts.volume);
        if (elapsed >= opts.fadeInSeconds) window.clearInterval(this.fadeTimer);
      }, 250);
    }
    if (opts.vibrate && typeof navigator !== 'undefined' && 'vibrate' in navigator) {
      const buzz = () => navigator.vibrate?.([600, 300, 600]);
      buzz();
      this.vibrateTimer = window.setInterval(buzz, 2000);
    }
  }

  stop(): void {
    window.clearInterval(this.fadeTimer);
    if (this.vibrateTimer !== undefined) {
      window.clearInterval(this.vibrateTimer);
      navigator.vibrate?.(0);
    }
    this.fadeTimer = this.vibrateTimer = undefined;
    if (this.audio) {
      this.audio.pause();
      this.audio.currentTime = 0;
    }
  }

  get playing(): boolean {
    return !!this.audio && !this.audio.paused;
  }

  private ensure(): HTMLAudioElement {
    if (!this.audio) {
      this.audio = new Audio();
      this.audio.preload = 'auto';
      this.audio.setAttribute('playsinline', '');
    }
    return this.audio;
  }
}
