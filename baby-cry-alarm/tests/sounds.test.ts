// @vitest-environment node
import { createHash } from "node:crypto";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { describe, expect, it } from "vitest";
import { PROVENANCE, resolveVoice, SOUND_IDS, VOICES, voiceById } from "../src/sounds";
import { makeRng } from "../src/missions";

const PUBLIC = join(__dirname, "..", "public");
const REDISTRIBUTABLE = new Set(["CC0 1.0", "Public domain", "CC BY 4.0", "CC BY-SA 4.0"]);

describe("baby recordings", () => {
  it("ships at least three distinct baby voices", () => {
    expect(VOICES.length).toBeGreaterThanOrEqual(3);
    expect(new Set(SOUND_IDS).size).toBe(VOICES.length);
  });

  it.each(PROVENANCE.sounds.map((s) => [s.id, s] as const))("%s matches its provenance record", (_id, s) => {
    const path = join(PUBLIC, s.file);
    expect(existsSync(path)).toBe(true);
    const bytes = readFileSync(path);
    expect(createHash("sha256").update(bytes).digest("hex")).toBe(s.sha256);
    // MP3: ID3 tag or an MPEG frame sync.
    const isMp3 = bytes.subarray(0, 3).toString("latin1") === "ID3" || (bytes[0] === 0xff && (bytes[1] & 0xe0) === 0xe0);
    expect(isMp3).toBe(true);
  });

  it.each(PROVENANCE.sounds.map((s) => [s.id, s] as const))("%s is an authentic, licensed, network-sourced recording", (_id, s) => {
    expect(s.origin).toBe("authenticRecorded");
    expect(s.licenseStatus).toBe("verifiedRedistributable");
    expect(REDISTRIBUTABLE.has(s.license)).toBe(true);
    expect(s.source.download).toMatch(/^https:\/\/upload\.wikimedia\.org\//);
    expect(s.source.page).toMatch(/^https:\/\/commons\.wikimedia\.org\/wiki\/File:/);
    expect(s.source.sha1).toMatch(/^[0-9a-f]{40}$/);
    expect(s.author.length).toBeGreaterThan(0);
    if (s.attributionRequired) expect(s.license).toMatch(/^CC BY/);
  });

  it("records the fetch channel", () => {
    expect(PROVENANCE.channel).toBe("openNetworkFetch");
  });

  it("every voice has a name and description", () => {
    for (const id of SOUND_IDS) {
      const v = voiceById(id);
      expect(v.name).toBeTruthy();
      expect(v.blurb).toBeTruthy();
    }
  });

  it("surprise baby avoids repeating the previous one", () => {
    const rng = makeRng(9);
    for (let i = 0; i < 50; i++) {
      expect(resolveVoice("shuffle", rng, "newborn")).not.toBe("newborn");
    }
    expect(resolveVoice("fussy", rng)).toBe("fussy");
  });
});
