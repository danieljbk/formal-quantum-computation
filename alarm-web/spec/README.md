# Acceptance spec

Lean 4 models of the build contract (`CageRules`) and the product request (`UserPrompt`) this app was
built against. They are standalone reference files and are not part of the repository's `lake` libraries.

| Requirement | Where it is met |
| --- | --- |
| Manifest + type config | `package.json`, `tsconfig.json` |
| ≥ 8 modular sources | `src/*.ts`, `src/components/*.tsx` (17 files) |
| Tests pass | `npm test` (Vitest, `src/__tests__`) |
| Bundle emitted | `npm run build` → `dist/index.html` |
| Assets fetched over the network, not generated | 4 recordings downloaded from Wikimedia Commons |
| Verified redistributable grant | CC0 / public domain / CC BY-SA 4.0, SHA-1 checked against Commons |
| ≥ 4 assets, provenance logged | `provenance.json`, checked by `src/__tests__/sounds.test.ts` |
| Baby crying instead of a standard alarm | `src/sounds.ts`, `src/audio.ts` |
| User chooses the baby voice | `src/components/SoundPicker.tsx` |
| Cries in the morning / whenever an alarm is set | `src/engine.ts`, default 7:00 weekday alarm |
| Matches a leading alarm app's capabilities | missions, snooze limits, gradual volume, wake-up check, nap timer, wake report |
