import provenance from "./sounds.provenance.json";
import type { SoundId, VoiceChoice } from "./types";

export interface BabyVoice {
  id: SoundId;
  name: string;
  blurb: string;
  emoji: string;
  /** Path relative to the app root (works with Vite's relative base). */
  file: string;
  durationSec: number;
  author: string;
  license: string;
  licenseUrl: string;
  sourcePage: string;
  attributionRequired: boolean;
}

const COPY: Record<SoundId, Pick<BabyVoice, "name" | "blurb" | "emoji">> = {
  newborn: {
    name: "Newborn wail",
    blurb: "High, rhythmic newborn cry. Starts loud, stays loud.",
    emoji: "👶",
  },
  hungry: {
    name: "Hungry build-up",
    blurb: "Starts with a whimper and builds into one long, complaining cry.",
    emoji: "🍼",
  },
  fussy: {
    name: "Fussy & let down",
    blurb: "Medium sobbing with hiccups. The slow-burn wake-up.",
    emoji: "🥺",
  },
  kunjappi: {
    name: "Kunjappi",
    blurb: "A real newborn, recorded by their parent. Short breaths, big lungs.",
    emoji: "😭",
  },
};

type ProvenanceEntry = (typeof provenance.sounds)[number];

function toVoice(p: ProvenanceEntry): BabyVoice {
  const id = p.id as SoundId;
  return {
    id,
    ...COPY[id],
    file: p.file,
    durationSec: p.durationSec,
    author: p.author,
    license: p.license,
    licenseUrl: p.licenseUrl,
    sourcePage: p.source.page,
    attributionRequired: p.attributionRequired,
  };
}

export const VOICES: BabyVoice[] = provenance.sounds.map(toVoice);
export const SOUND_IDS: SoundId[] = VOICES.map((v) => v.id);
export const PROVENANCE = provenance;

export function voiceById(id: SoundId): BabyVoice {
  const v = VOICES.find((x) => x.id === id);
  if (!v) throw new Error(`Unknown baby voice: ${id}`);
  return v;
}

export function isSoundId(x: unknown): x is SoundId {
  return typeof x === "string" && (SOUND_IDS as string[]).includes(x);
}

export function isVoiceChoice(x: unknown): x is VoiceChoice {
  return x === "shuffle" || isSoundId(x);
}

/** Resolve "shuffle" to a concrete baby, avoiding an immediate repeat when possible. */
export function resolveVoice(choice: VoiceChoice, rng: () => number, previous?: SoundId): SoundId {
  if (choice !== "shuffle") return choice;
  const pool = SOUND_IDS.length > 1 && previous ? SOUND_IDS.filter((id) => id !== previous) : SOUND_IDS;
  return pool[Math.floor(rng() * pool.length)];
}

export function voiceLabel(choice: VoiceChoice): string {
  return choice === "shuffle" ? "Surprise baby" : voiceById(choice).name;
}
