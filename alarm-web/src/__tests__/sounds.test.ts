import { createHash } from 'node:crypto';
import { existsSync, readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import { describe, expect, it } from 'vitest';
import { BABY_VOICES, getVoice, isSoundId } from '../sounds';
import { fadeVolume } from '../audio';

const root = resolve(__dirname, '../..');
const provenance = JSON.parse(readFileSync(resolve(root, 'provenance.json'), 'utf8')) as {
  assets: { id: string; file: string; sha256: string; sourceUrl: string; license: string; redistributable: boolean }[];
};

describe('baby voices', () => {
  it('offers at least four selectable voices', () => {
    expect(BABY_VOICES.length).toBeGreaterThanOrEqual(4);
    expect(new Set(BABY_VOICES.map((v) => v.id)).size).toBe(BABY_VOICES.length);
    expect(isSoundId('newborn')).toBe(true);
    expect(isSoundId('foghorn')).toBe(false);
    expect(getVoice('kunjappi').name).toBe('Dawn wail');
  });

  it.each(BABY_VOICES.map((v) => [v.id, v] as const))('%s is a real, logged, redistributable recording', (_id, voice) => {
    const path = resolve(root, 'public', voice.file);
    expect(existsSync(path)).toBe(true);
    const bytes = readFileSync(path);
    // MPEG audio: ID3 tag or frame sync.
    expect(bytes.subarray(0, 3).toString('latin1') === 'ID3' || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0)).toBe(true);
    const entry = provenance.assets.find((a) => a.id === voice.id);
    expect(entry).toBeDefined();
    expect(entry!.file).toBe(`public/${voice.file}`);
    expect(createHash('sha256').update(bytes).digest('hex')).toBe(entry!.sha256);
    expect(entry!.sourceUrl).toMatch(/^https:\/\/upload\.wikimedia\.org\//);
    expect(entry!.redistributable).toBe(true);
    expect(entry!.license).toBe(voice.license);
  });
});

describe('fade-in', () => {
  it('ramps from 10% to the target volume', () => {
    expect(fadeVolume(0, 20, 1)).toBeCloseTo(0.1);
    expect(fadeVolume(10, 20, 1)).toBeCloseTo(0.55);
    expect(fadeVolume(30, 20, 0.8)).toBeCloseTo(0.8);
    expect(fadeVolume(0, 0, 0.6)).toBe(0.6);
  });
});
