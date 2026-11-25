import raw from './voices.json';

export interface Voice {
  id: string;
  name: string;
  persona: string;
  file: string;
  sourceUrl: string;
  pageUrl: string;
  author: string;
  license: string;
}

export const VOICES: readonly Voice[] = raw as Voice[];
export const VOICE_IDS: readonly string[] = VOICES.map((v) => v.id);

export function voiceById(id: string): Voice {
  return VOICES.find((v) => v.id === id) ?? VOICES[0];
}
