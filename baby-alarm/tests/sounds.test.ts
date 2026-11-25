// @vitest-environment node
import { existsSync, readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { describe, expect, it } from "vitest";
import credits from "../src/data/credits.json";
import { DEFAULT_SOUND_ID, SOUNDS, SOUND_CATEGORIES, soundById, soundsInCategory } from "../src/data/sounds";

describe("baby voice catalog", () => {
  it("ships at least 8 real recordings across at least 3 categories", () => {
    expect(SOUNDS.length).toBeGreaterThanOrEqual(8);
    const used = SOUND_CATEGORIES.filter((c) => soundsInCategory(c.id).length > 0);
    expect(used.length).toBeGreaterThanOrEqual(3);
  });

  it("only uses externally fetched, license-verified CC0 assets whose bytes match the manifest", () => {
    for (const c of credits) {
      expect(c.licenseVerified).toBe(true);
      expect(c.license).toBe("CC0 1.0");
      expect(c.source).toMatch(/^https:\/\/freesound\.org\/s\/\d+\/$/);
      const path = join(fileURLToPath(new URL("..", import.meta.url)), "public", "sounds", c.file);
      expect(existsSync(path)).toBe(true);
      const buf = readFileSync(path);
      expect(buf.length).toBe(c.bytes);
      expect(createHash("sha256").update(buf).digest("hex")).toBe(c.sha256);
    }
  });

  it("falls back to the default voice for unknown ids", () => {
    expect(soundById("nope").id).toBe(DEFAULT_SOUND_ID);
  });
});
