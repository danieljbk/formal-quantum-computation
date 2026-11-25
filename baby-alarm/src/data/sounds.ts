import credits from "./credits.json";

export type SoundCategoryId = "newborn" | "wail" | "fussy" | "toddler";

export interface SoundCategory {
  id: SoundCategoryId;
  name: string;
  blurb: string;
  emoji: string;
}

export interface BabySound {
  id: string;
  name: string;
  category: SoundCategoryId;
  /** 1 = gentle nudge, 5 = nobody sleeps through this */
  intensity: 1 | 2 | 3 | 4 | 5;
  file: string;
  credit: { title: string; creator: string; source: string; license: string; licenseUrl: string };
}

export const SOUND_CATEGORIES: SoundCategory[] = [
  { id: "newborn", name: "Newborn", blurb: "Thin, insistent first-weeks cries", emoji: "👶" },
  { id: "wail", name: "Full Wail", blurb: "Red-faced, full-lung crying", emoji: "😭" },
  { id: "fussy", name: "Fussy", blurb: "Whimpers that build if ignored", emoji: "🥺" },
  { id: "toddler", name: "Toddler", blurb: "Big-kid sobs and meltdowns", emoji: "🧒" },
];

const META: Record<string, Pick<BabySound, "name" | "category" | "intensity">> = {
  "newborn-first-cry": { name: "First Cry", category: "newborn", intensity: 3 },
  "newborn-hungry": { name: "Hungry Newborn", category: "newborn", intensity: 4 },
  "newborn-ward": { name: "Maternity Ward", category: "newborn", intensity: 3 },
  "wail-hard-and-long": { name: "Hard & Long", category: "wail", intensity: 5 },
  "wail-full-lungs": { name: "Full Lungs", category: "wail", intensity: 5 },
  "wail-loud-burst": { name: "Loud Burst", category: "wail", intensity: 4 },
  "fussy-winding-down": { name: "Winding Down", category: "fussy", intensity: 2 },
  "fussy-three-months": { name: "Three Months Old", category: "fussy", intensity: 1 },
  "fussy-whimper": { name: "Whimper", category: "fussy", intensity: 2 },
  "toddler-wants-mom": { name: "Wants Mom", category: "toddler", intensity: 3 },
  "toddler-sobbing": { name: "Sobbing", category: "toddler", intensity: 4 },
  "toddler-meltdown": { name: "Bathtime Meltdown", category: "toddler", intensity: 5 },
};

interface CreditEntry {
  id: string;
  file: string;
  title: string;
  creator: string;
  source: string;
  license: string;
  licenseUrl: string;
  licenseVerified: boolean;
}

export const SOUNDS: BabySound[] = (credits as CreditEntry[])
  .filter((c) => c.licenseVerified && META[c.id])
  .map((c) => ({
    id: c.id,
    file: c.file,
    ...META[c.id],
    credit: { title: c.title, creator: c.creator, source: c.source, license: c.license, licenseUrl: c.licenseUrl },
  }));

export const DEFAULT_SOUND_ID = "newborn-hungry";

export function soundById(id: string): BabySound {
  return SOUNDS.find((s) => s.id === id) ?? SOUNDS.find((s) => s.id === DEFAULT_SOUND_ID) ?? SOUNDS[0];
}

export function soundsInCategory(category: SoundCategoryId): BabySound[] {
  return SOUNDS.filter((s) => s.category === category);
}
