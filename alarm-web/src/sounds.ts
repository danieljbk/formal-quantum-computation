import type { SoundId } from './types';

export interface BabyVoice {
  id: SoundId;
  name: string;
  description: string;
  /** Path relative to the app's base URL. */
  file: string;
  durationSeconds: number;
  credit: string;
  license: string;
  sourcePage: string;
}

/**
 * The baby voices a user can wake up to. Every file is a real recording fetched from
 * Wikimedia Commons under a redistributable license; see `provenance.json`.
 */
export const BABY_VOICES: readonly BabyVoice[] = [
  {
    id: 'newborn',
    name: 'Newborn',
    description: 'A brand-new baby, high-pitched and insistent.',
    file: 'sounds/newborn.mp3',
    durationSeconds: 23.1,
    credit: 'the_yura (Freesound)',
    license: 'CC0 1.0',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Crying_newborn_baby.ogg',
  },
  {
    id: 'wanting',
    name: 'Hungry',
    description: 'A long, wanting cry that builds and builds.',
    file: 'sounds/wanting.mp3',
    durationSeconds: 18.5,
    credit: 'natalie (pdsounds.org)',
    license: 'Public domain',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Baby_long_wanting_cry.ogg',
  },
  {
    id: 'disappointed',
    name: 'Disappointed',
    description: 'Sobbing with real feeling. Hard to ignore.',
    file: 'sounds/disappointed.mp3',
    durationSeconds: 48.4,
    credit: 'natalie (pdsounds.org)',
    license: 'Public domain',
    sourcePage: 'https://commons.wikimedia.org/wiki/File:Babys_disappointed_crying.oga',
  },
  {
    id: 'kunjappi',
    name: 'Dawn wail',
    description: 'A newborn recorded at sunrise — a full minute of crying.',
    file: 'sounds/kunjappi.mp3',
    durationSeconds: 54.0,
    credit: 'Manoj Karingamadathil',
    license: 'CC BY-SA 4.0',
    sourcePage:
      'https://commons.wikimedia.org/wiki/File:Newborn_baby_crying_sounds_20190831_061900.wav',
  },
];

export const DEFAULT_SOUND: SoundId = 'newborn';

export function getVoice(id: SoundId): BabyVoice {
  return BABY_VOICES.find((v) => v.id === id) ?? BABY_VOICES[0];
}

export function isSoundId(value: unknown): value is SoundId {
  return typeof value === 'string' && BABY_VOICES.some((v) => v.id === value);
}
