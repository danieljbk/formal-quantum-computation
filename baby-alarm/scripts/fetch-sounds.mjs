#!/usr/bin/env node
// Downloads the baby-cry recordings used by the app from Freesound and
// verifies, on each sound's public page, that it is released under CC0 1.0
// (public-domain dedication, freely redistributable). Writes the audio to
// public/sounds/ and the provenance record to src/data/credits.json.
//
// Usage: node scripts/fetch-sounds.mjs
// The recordings are committed, so this only needs re-running to refresh them.

import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "..");
const UA = { "User-Agent": "cry-awake-asset-fetcher/1.0" };
const CC0_URL = "creativecommons.org/publicdomain/zero/1.0";

/** Selected via the Openverse audio API (license=cc0) and checked by hand for content. */
const SOURCES = [
  { id: "newborn-first-cry", freesoundId: 391181, preview: "391/391181_7227448", title: "newborn baby crying", creator: "gumballworld" },
  { id: "newborn-hungry", freesoundId: 431644, preview: "431/431644_4451798", title: "newborn baby crying.wav", creator: "blukotek" },
  { id: "newborn-ward", freesoundId: 211529, preview: "211/211529_2451161", title: "Crying newborn baby child 1.WAV", creator: "the_yura" },
  { id: "wail-hard-and-long", freesoundId: 151080, preview: "151/151080_2661659", title: "01 baby crying hard and long.wav", creator: "PickleJones" },
  { id: "wail-full-lungs", freesoundId: 321712, preview: "321/321712_40875", title: "baby crying", creator: "eguaus" },
  { id: "wail-loud-burst", freesoundId: 436915, preview: "436/436915_1083532", title: "baby crying loud", creator: "organicmanpl" },
  { id: "fussy-winding-down", freesoundId: 151081, preview: "151/151081_2661659", title: "01 baby crying winding down.wav", creator: "PickleJones" },
  { id: "fussy-three-months", freesoundId: 146926, preview: "146/146926_557200", title: "Baby Noises3 (3 month old)", creator: "mushroomjesus" },
  { id: "fussy-whimper", freesoundId: 346663, preview: "346/346663_2104797", title: "Baby Cry.wav", creator: "deleted_user_2104797" },
  { id: "toddler-wants-mom", freesoundId: 569979, preview: "569/569979_11735858", title: "Toddler Victoria Crying for Mom and Run Away from her Bedroom", creator: "Alexadiaz12" },
  { id: "toddler-sobbing", freesoundId: 429981, preview: "429/429981_4298084", title: "Child crying.wav", creator: "BeeProductive" },
  { id: "toddler-meltdown", freesoundId: 609635, preview: "609/609635_11735858", title: "3 Years Old Girl has Meltdown in Bathroom", creator: "Alexadiaz12" },
];

async function fetchWithRetry(url, attempts = 4) {
  let lastErr;
  for (let i = 0; i < attempts; i++) {
    try {
      const res = await fetch(url, { headers: UA, redirect: "follow" });
      if (!res.ok) throw new Error(`${res.status} ${res.statusText} for ${url}`);
      return res;
    } catch (err) {
      lastErr = err;
      await new Promise((r) => setTimeout(r, 1500 * 2 ** i));
    }
  }
  throw lastErr;
}

async function main() {
  await mkdir(join(root, "public", "sounds"), { recursive: true });
  const credits = [];
  for (const s of SOURCES) {
    const page = `https://freesound.org/s/${s.freesoundId}/`;
    const html = await (await fetchWithRetry(page)).text();
    if (!html.includes(CC0_URL)) throw new Error(`License check failed: ${page} does not link ${CC0_URL}`);

    const url = `https://cdn.freesound.org/previews/${s.preview}-hq.mp3`;
    const buf = Buffer.from(await (await fetchWithRetry(url)).arrayBuffer());
    if (buf.length < 20_000) throw new Error(`Suspiciously small download (${buf.length} bytes): ${url}`);
    const file = `${s.id}.mp3`;
    await writeFile(join(root, "public", "sounds", file), buf);

    credits.push({
      id: s.id,
      file,
      title: s.title,
      creator: s.creator,
      source: page,
      downloadUrl: url,
      license: "CC0 1.0",
      licenseUrl: `https://${CC0_URL}/`,
      licenseVerified: true,
      sha256: createHash("sha256").update(buf).digest("hex"),
      bytes: buf.length,
    });
    console.log(`ok  ${file}  ${buf.length} bytes  CC0 verified at ${page}`);
  }
  await writeFile(join(root, "src", "data", "credits.json"), JSON.stringify(credits, null, 2) + "\n");
  console.log(`wrote ${credits.length} credits`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
