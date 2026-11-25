import { describe, expect, it } from 'vitest';
import voices from '../src/audio/voices.json';
import { CAPABILITIES } from '../src/core/capabilities';
import { existsSync, statSync } from 'node:fs';
import { resolve } from 'node:path';

describe('reference capability parity', () => {
  it('covers at least 12 capabilities with unique ids', () => {
    expect(CAPABILITIES.length).toBeGreaterThanOrEqual(12);
    expect(new Set(CAPABILITIES.map((c) => c.id)).size).toBe(CAPABILITIES.length);
  });
});

describe('baby voice assets', () => {
  it('ships at least six fetched recordings, all present and credited', () => {
    expect(voices.length).toBeGreaterThanOrEqual(6);
    for (const v of voices) {
      const file = resolve(__dirname, '../public', v.file);
      expect(existsSync(file), v.file).toBe(true);
      expect(statSync(file).size).toBeGreaterThan(50_000);
      expect(v.sourceUrl).toMatch(/^https:\/\//);
      expect(v.author.length).toBeGreaterThan(0);
      expect(v.license.length).toBeGreaterThan(0);
    }
  });
});
