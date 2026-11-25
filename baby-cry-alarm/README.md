# Baby Cry Alarm

An alarm clock whose alarm is a real recorded baby crying. You pick the baby, set
the time, and the crying only stops once you have proved you're awake.

A browser app (TypeScript + React + Vite) built for phones. Add it to the home screen
for a full-screen, app-like feel.

## Features

- **Alarms**: any time, one-off or repeating on chosen days (presets for weekdays,
  weekends and every day), with labels and on/off switches.
- **A morning alarm out of the box**: first launch creates "Good morning", 7:00 on weekdays.
- **Choose the baby**: four real recordings, each with a 6-second preview, or
  *Surprise baby*, which picks a different one each time.
- **Wake-up missions** that must be finished before the crying stops:
  math (3 difficulty levels, 1–10 problems), typing a phrase (paste blocked), or
  rocking the baby (shake the phone or tap the cradle 5–100 times).
- **Snooze** with a configurable interval and limit, shown as "3 left".
- **Gradual volume** (fade in over 15/30/60 s) using Web Audio, so it also works on
  iOS, where `<audio>.volume` is read-only. Optional vibration.
- **Quick nap alarms** (+5/10/20/30 min), **skip next** for repeating alarms, and a
  "next cry in 7 h 12 min" countdown.
- **Bedside mode**: keeps the screen awake (Screen Wake Lock) for an overnight alarm.
- **Test this alarm now** from the editor.

### Web platform limits

Browsers only let a page make sound after the user has tapped it once. The app
asks for that tap ("Tap to let the baby cry"). A web page can't ring while it's
closed, so leave the tab open (Bedside mode helps). Background tabs may be
throttled; the scheduler catches up on alarms that came due while it was asleep.

## The recordings

All four sounds are **authentic recordings of real babies**, fetched over the
network from Wikimedia Commons. Each was checked against the SHA-1 that Commons
publishes, then loudness-normalized and encoded to MP3. Nothing was synthesized.

| Voice | Source file | Author | License |
|---|---|---|---|
| Newborn wail | [Crying newborn baby.ogg](https://commons.wikimedia.org/wiki/File:Crying_newborn_baby.ogg) | the_yura | CC0 1.0 |
| Hungry build-up | [Baby long wanting cry.ogg](https://commons.wikimedia.org/wiki/File:Baby_long_wanting_cry.ogg) | natalie | Public domain |
| Fussy & let down | [Babys disappointed crying.oga](https://commons.wikimedia.org/wiki/File:Babys_disappointed_crying.oga) | natalie | Public domain |
| Kunjappi | [Newborn baby crying sounds 20190831 061900.wav](https://commons.wikimedia.org/wiki/File:Newborn_baby_crying_sounds_20190831_061900.wav) | Manoj Karingamadathil | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

`public/sounds/kunjappi.mp3` is an adaptation of Manoj Karingamadathil's recording
and is shared under CC BY-SA 4.0. The app's code is Apache-2.0, like the rest of this repository.

Full provenance (source URLs, upstream origin, Commons SHA-1, recording date,
transform, output SHA-256) is in [`src/sounds.provenance.json`](src/sounds.provenance.json).
`npm run fetch-sounds` reproduces the files, and `tests/sounds.test.ts` checks that
the shipped files match that log.

## Develop

```bash
npm ci
npm run dev        # local dev server
npm test           # vitest: scheduling, snooze, missions, storage, provenance, UI
npm run build      # type-check + production bundle in dist/
```

## Layout

```
src/
  types.ts          Alarm, mission, snooze types
  schedule.ts       next occurrence, due-in-window, countdown/repeat formatting
  engine.ts         ring / snooze / dismiss / skip state transitions (pure)
  missions.ts       math, typing and rock missions (seeded, testable)
  sounds.ts         baby voice catalog, built from the provenance log
  audio.ts          Web Audio player with fade-in and <audio> fallback
  storage.ts        localStorage persistence + validation, first-run morning alarm
  App.tsx           scheduler loop and screens
  components/       AlarmCard, AlarmEditor, VoicePicker, RingingScreen, MissionPanel, Credits
tests/              vitest suites
public/sounds/      the four recordings
scripts/fetch-sounds.sh
```
