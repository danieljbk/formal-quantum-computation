import { voiceById } from './voices';

type Ctx = AudioContext;

interface Layer {
  source: AudioBufferSourceNode;
  gain: GainNode;
}

/**
 * Plays the fetched baby recordings. Uses Web Audio so that volume can be
 * ramped on iOS (where HTMLAudioElement.volume is read-only). Browsers only
 * allow sound after a user gesture, so `unlock()` is called from the first tap.
 */
export class AlarmAudioEngine {
  private ctx: Ctx | null = null;
  private buffers = new Map<string, Promise<AudioBuffer | null>>();
  private layers = new Map<string, Layer>();
  private preview: AudioBufferSourceNode | null = null;
  private wantedVoices: string[] = [];
  private unlocked = false;

  private context(): Ctx | null {
    if (this.ctx) return this.ctx;
    const Ctor: typeof AudioContext | undefined =
      typeof window !== 'undefined' ? window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext : undefined;
    if (!Ctor) return null;
    this.ctx = new Ctor();
    return this.ctx;
  }

  get isUnlocked(): boolean {
    return this.unlocked && this.ctx?.state === 'running';
  }

  async unlock(): Promise<boolean> {
    const ctx = this.context();
    if (!ctx) return false;
    try {
      if (ctx.state !== 'running') await ctx.resume();
      // A one-sample silent buffer primes iOS output.
      const src = ctx.createBufferSource();
      src.buffer = ctx.createBuffer(1, 1, 22050);
      src.connect(ctx.destination);
      src.start(0);
      this.unlocked = ctx.state === 'running';
    } catch {
      this.unlocked = false;
    }
    return this.unlocked;
  }

  private load(voiceId: string): Promise<AudioBuffer | null> {
    const existing = this.buffers.get(voiceId);
    if (existing) return existing;
    const ctx = this.context();
    const p = (async () => {
      if (!ctx) return null;
      try {
        const res = await fetch(voiceById(voiceId).file);
        const data = await res.arrayBuffer();
        return await ctx.decodeAudioData(data);
      } catch {
        return null;
      }
    })();
    this.buffers.set(voiceId, p);
    return p;
  }

  preload(voiceIds: readonly string[]): void {
    voiceIds.forEach((id) => void this.load(id));
  }

  /** Make exactly `voiceIds` play (looping) at `volume`, smoothly ramping gain. */
  setLayers(voiceIds: readonly string[], volume: number): void {
    const ctx = this.context();
    if (!ctx) return;
    if (ctx.state === 'suspended') void ctx.resume();
    this.wantedVoices = [...voiceIds];
    for (const [id, layer] of this.layers) {
      if (!voiceIds.includes(id)) {
        layer.gain.gain.setTargetAtTime(0, ctx.currentTime, 0.2);
        layer.source.stop(ctx.currentTime + 1);
        this.layers.delete(id);
      }
    }
    voiceIds.forEach((id, i) => {
      // Joining voices sit slightly under the primary one.
      const target = Math.max(0, Math.min(1, volume * (i === 0 ? 1 : 0.8)));
      const layer = this.layers.get(id);
      if (layer) {
        layer.gain.gain.setTargetAtTime(target, ctx.currentTime, 0.5);
        return;
      }
      void this.load(id).then((buffer) => {
        if (!buffer || this.layers.has(id) || !this.wantedVoices.includes(id)) return;
        const gain = ctx.createGain();
        gain.gain.value = 0;
        gain.connect(ctx.destination);
        const source = ctx.createBufferSource();
        source.buffer = buffer;
        source.loop = true;
        source.connect(gain);
        source.start(0, (i * 3.7) % Math.max(1, buffer.duration));
        gain.gain.setTargetAtTime(target, ctx.currentTime, 0.5);
        this.layers.set(id, { source, gain });
      });
    });
  }

  stop(): void {
    const ctx = this.ctx;
    this.wantedVoices = [];
    for (const layer of this.layers.values()) {
      try {
        layer.source.stop();
      } catch {
        /* already stopped */
      }
    }
    this.layers.clear();
    if (ctx && ctx.state === 'suspended') void ctx.resume();
  }

  /** Play a few seconds of a voice so the user can pick one. */
  async previewVoice(voiceId: string, seconds = 4): Promise<void> {
    await this.unlock();
    const ctx = this.context();
    const buffer = await this.load(voiceId);
    if (!ctx || !buffer) return;
    this.stopPreview();
    const gain = ctx.createGain();
    gain.gain.value = 0.6;
    gain.gain.setTargetAtTime(0, ctx.currentTime + seconds - 0.5, 0.15);
    gain.connect(ctx.destination);
    const src = ctx.createBufferSource();
    src.buffer = buffer;
    src.connect(gain);
    src.start(0, 0, seconds);
    this.preview = src;
  }

  stopPreview(): void {
    try {
      this.preview?.stop();
    } catch {
      /* already stopped */
    }
    this.preview = null;
  }

  vibrate(on: boolean): void {
    if (typeof navigator === 'undefined' || !('vibrate' in navigator)) return;
    navigator.vibrate(on ? [600, 300, 600, 300] : 0);
  }
}

export const audioEngine = new AlarmAudioEngine();
