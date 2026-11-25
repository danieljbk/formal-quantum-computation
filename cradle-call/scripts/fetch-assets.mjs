#!/usr/bin/env node
// Downloads every baby-cry recording listed in src/audio/voices.json from its
// public source over the network and stores it under public/<file>.
//
// Nothing here synthesises audio: each output file is the downloaded
// recording. Sources that are not MP3 (Ogg Vorbis / WAV) are transcoded to
// MP3 with ffmpeg so that iOS Safari can decode them; the sound itself is
// unchanged.
//
// Usage: npm run fetch-assets [-- --force]
import { execFileSync } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, extname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const voices = JSON.parse(readFileSync(join(root, 'src/audio/voices.json'), 'utf8'));
const force = process.argv.includes('--force');
const UA = 'cradle-call-asset-fetcher/1.0';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function download(url) {
  for (let attempt = 0; attempt < 8; attempt++) {
    const res = await fetch(url, { headers: { 'User-Agent': UA }, redirect: 'follow' });
    if (res.ok) return Buffer.from(await res.arrayBuffer());
    if (res.status !== 429 && res.status < 500) throw new Error(`${res.status} ${res.statusText} for ${url}`);
    const wait = 15_000 * (attempt + 1);
    console.warn(`  ${res.status} from ${new URL(url).host}, retrying in ${wait / 1000}s`);
    await sleep(wait);
  }
  throw new Error(`gave up on ${url}`);
}

let failures = 0;
for (const v of voices) {
  const out = join(root, 'public', v.file);
  if (existsSync(out) && !force) {
    console.log(`= ${v.id}: ${v.file} already present`);
    continue;
  }
  mkdirSync(dirname(out), { recursive: true });
  try {
    console.log(`↓ ${v.id}: ${v.sourceUrl}`);
    const bytes = await download(v.sourceUrl);
    const ext = extname(new URL(v.sourceUrl).pathname).toLowerCase();
    if (ext === '.mp3') {
      writeFileSync(out, bytes);
    } else {
      const tmp = `${out}.src${ext}`;
      writeFileSync(tmp, bytes);
      execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmp, '-vn', '-codec:a', 'libmp3lame', '-q:a', '4', out]);
      rmSync(tmp);
    }
    console.log(`✓ ${v.id} → public/${v.file}`);
  } catch (err) {
    failures++;
    console.error(`✗ ${v.id}: ${err.message}`);
  }
  await sleep(2_000);
}
process.exit(failures ? 1 : 0);
