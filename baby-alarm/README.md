# Cry Awake

Cry Awake is a mission alarm clock that wakes you with a **real baby crying**. It runs in the browser with an iOS-style layout. The baby keeps crying until you finish a wake-up mission. The alarm-clock genre is the reference point, but the name, art and code are all original.

```bash
npm install
npm run dev        # http://localhost:5173
npm run build      # typecheck + production bundle in dist/
npm test -- --run  # vitest suite
```

## Features

- **Alarms**: time, repeat days, label, snooze length and limit, one-shot alarms, a countdown to the next cry, and a **Test** button that rings an alarm immediately.
- **Baby voices**: 12 real recordings in 4 categories (Newborn, Full Wail, Fussy, Toddler). You can preview each one and pick a voice per alarm or as the default.
- **Ring screen**: loops the chosen cry with a gradual volume ramp and repeats a vibration pattern. You can snooze until the limit runs out.
- **6 wake-up missions**, each with three difficulty levels: Math, Shake (motion sensor, or tap if the device has none), Typing (paste is blocked), Memory pattern, Rock the Baby (press and hold), and Sequence.
- **Vibration patterns**: Heartbeat, Lullaby rock and Siren, using the Vibration API. iOS Safari has no Vibration API, so the screen pulses instead.
- **Wake stats**: streak, total wake-ups, average time to get up, no-snooze rate, a 7-day chart and a full history.
- **Persistence**: alarms, settings and history are saved in `localStorage`. If saved data is corrupt or storage is blocked, the app falls back to defaults.
- **Bedside mode**: a dim clock that holds a Screen Wake Lock so alarms can ring overnight. Browsers can't wake a closed tab, so the page has to stay open.

## Audio provenance

`scripts/fetch-sounds.mjs` downloads every recording from Freesound. For each sound it checks that the public page links the **CC0 1.0** public-domain dedication, then writes `src/data/credits.json` with the source URL, creator, SHA-256 and byte size. `tests/sounds.test.ts` re-checks every committed file against that manifest. None of the audio is synthesized or a placeholder. The Settings screen lists credits for each sound.

## Spec

The Lean models in `spec/` record the requirements this app was built against.

| `CageRules.BuilderState` field | Where |
| --- | --- |
| `manifestPresent` / `typeConfigPresent` | `package.json`, `tsconfig.json` |
| `modularSources ≥ 10` | 25 TS/TSX modules under `src/` |
| `testsPass` | `tests/` (7 files, 35 tests) |
| `bundleEmitted` | `npm run build` → `dist/index.html` |
| `assetOrigin = externalFetched`, `assetGrant = verifiedRedistributable` | `scripts/fetch-sounds.mjs`, `src/data/credits.json` |
| `assetCount ≥ 8`, `categoryCount ≥ 3` | 12 sounds, 4 categories (`src/data/sounds.ts`) |
| `interactiveChallenges ≥ 5` | 6 missions (`src/components/challenges/`) |
| `persistentSettings` | `src/lib/storage.ts` |
| `analyticsHistory` | `src/lib/analytics.ts`, `StatsView` |
| `vibrationalPattern` | `src/lib/vibration.ts` |
| `directExecution` | runs straight from `dist/` (relative `base`), with a **Test** ring button |

`UserPrompt.AppRequest` is covered by the cry alarm sound, the per-alarm voice picker, and alarms that fire at their scheduled time.
