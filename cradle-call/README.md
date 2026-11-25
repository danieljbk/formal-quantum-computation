# Cradle Call 👶⏰

A mission-gated alarm clock that wakes you with a **real crying baby**. Pick the baby, set the time, choose the missions, and the only way to make the crying stop is to get up and complete them.

It's a browser app (TypeScript + React + Vite) designed for iPhone-sized screens. Keep the page open with the screen on and it rings at the set time.

```bash
npm install
npm run dev        # http://localhost:5173
npm test           # vitest
npm run build      # type-check + bundle to dist/
npm run fetch-assets   # re-download the baby recordings from their sources
```

## How it works

- **Baby voices.** There are 8 real recordings, each downloaded from its public source by `scripts/fetch-assets.mjs`. The sources are listed in `src/audio/voices.json`. You choose a voice per alarm and can preview each one.
- **Escalation ramp** (`src/core/escalation.ts`). The cry gets louder in four stages: *Whimper → Fussing → Crying → Full nursery*. Volume rises within each stage. From the *Crying* stage on, other babies join in as extra layers.
- **Missions are the only way to dismiss.** There are six types: Bottle Math, Promise Typing, Toy Memory, Rock the Cradle (shake, or tap fast), Block Order and Crayon Check (Stroop). Each one has a difficulty and a round count. Every alarm needs at least one mission. The ringing screen has no stop button.
- **No way around it.** While an alarm is ringing or snoozed, you can't delete it or switch it off. Reloading the page brings the ringing back. Copy and paste are blocked in the typing mission.
- **Snooze** has a set length and a hard limit, which can be 0.
- **Mission idle timeout.** The cry drops to a low volume while you work on a mission. Stop interacting and it comes back at full escalation.
- **Wake-up check.** A few minutes after you dismiss the alarm it asks "Still awake?". If you don't answer within 60 s it rings again, and you have to complete the missions again.
- **Live status bar.** It shows the clock, a countdown to the next alarm, and the ringing, snooze or wake-check state.
- **History and stats, morning briefing, quick nap alarms, vibration, 12/24 h clock.**

The full capability list is in `src/core/capabilities.ts`.

### Browser limits

Web pages can only play sound after you've tapped the page, and they can't wake a locked phone. Tap **Settings → Enable sound** once and leave the page open. The app asks the browser to keep the screen on (Wake Lock) while an alarm is set. If timers were throttled, an alarm that's up to 5 minutes late still rings.

## Sound credits

| Voice | Author | Licence | Source |
| --- | --- | --- | --- |
| Newborn | the_yura (via Freesound) | CC0 1.0 | [Commons](https://commons.wikimedia.org/wiki/File:Crying_newborn_baby.ogg) |
| Hungry Boy | Mike Koenig | CC BY 3.0 | [SoundBible](https://soundbible.com/557-Baby-Crying.html) |
| First Cry | Daniel Simon | CC BY 3.0 | [SoundBible](https://soundbible.com/2130-Baby-Just-Born.html) |
| Raisin Crisis | Daniel D. Teoli Jr. | Public Domain Mark 1.0 | [Internet Archive](https://archive.org/details/toddler-crying-d.-d.-teoli-jr) |
| Marathon Crier | Jamma Jatta (uploader) | Public Domain Mark 1.0 | [Internet Archive](https://archive.org/details/BabyCryNew) |
| Disappointed | natalie (PDsounds) | Public domain | [Commons](https://commons.wikimedia.org/wiki/File:Babys_disappointed_crying.oga) |
| Long Wanting | natalie (PDsounds) | Public domain | [Commons](https://commons.wikimedia.org/wiki/File:Baby_long_wanting_cry.ogg) |
| 6:19 AM Special | Manoj Karingamadathil | CC BY-SA 4.0 | [Commons](https://commons.wikimedia.org/wiki/File:Newborn_baby_crying_sounds_20190831_061900.wav) |

The OGG and WAV originals were converted to MP3 with ffmpeg so iOS Safari can play them. Nothing else about the audio was changed.

## How the build spec maps to the code

| Spec field | Where |
| --- | --- |
| `manifestPresent`, `typeConfigPresent` | `package.json`, `tsconfig.json` |
| `modularViews ≥ 8` | `src/views/*` (12 view modules) and `src/missions/*` |
| `testsPass`, `bundleEmitted` | `npm test` (`tests/`), `npm run build` → `dist/index.html` |
| `assetOrigin = externalFetched`, `assetChannel = openNetworkFetch`, `assetCount ≥ 6` | `scripts/fetch-assets.mjs` + `src/audio/voices.json` (8 recordings), checked in `tests/capabilities.test.ts` |
| `challengeGates ≥ 5` | 6 mission types, `src/core/missions.ts` |
| `bypassPaths = 0` | `src/core/store.ts`, checked in `tests/store.test.ts` ("has no bypass") |
| `liveStatusSurface` | `src/views/StatusBar.tsx` |
| `escalation = multiStageRamp` | `src/core/escalation.ts`, checked in `tests/escalation.test.ts` |
| `referenceCapabilitiesMatched ≥ 12` | `src/core/capabilities.ts` (15 entries) |
| `directExecution` | runs straight from `dist/` in any browser |
| `alarmSound = babyCrying`, `userCanChooseBabyVoice` | `src/views/VoicePickerView.tsx` |
