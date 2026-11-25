# Wail Alarm

An alarm clock web app, styled like an iOS app, that wakes you with a **real baby crying** instead of a beep.
You pick which baby. Like the top-ranked alarm apps, it won't let you switch it off until you've proved you're awake.

## Features

- **Alarms**: time, label, repeat days (Once / Weekdays / Weekends / custom), on/off switch, and a "Rings in…" countdown.
  First run includes a 7:00 weekday "Morning" alarm you can turn on.
- **Choose the baby voice**: four real recordings with tap-to-preview (Newborn, Hungry, Disappointed, Dawn wail).
- **Wake-up missions** to stop the crying: Math, Typing (pasting blocked), Memory tiles, Shake (DeviceMotion, with
  a tap fallback on desktop), and Tap-the-bottle. Each has easy/medium/hard and 1–5 rounds.
- **Snooze rules**: length (1–30 min), a maximum count or unlimited, or snooze turned off.
- **Gradually louder**: the volume ramps up over 10–60 s, with vibration where the device supports it.
- **Wake-up check**: N minutes after you dismiss the alarm, it asks "Still awake?" If you don't answer within 60 s,
  the baby cries again.
- **Nap / quick alarm**: a one-off alarm that rings in N minutes.
- **Wake-up report**: mornings logged, average minutes to get up, total snoozes, no-snooze streak.
- **Bedside mode**: keeps the screen awake (Screen Wake Lock API) so the alarm can ring.
- Remembers alarms between visits in local storage, works at phone width with safe-area insets, and respects
  reduced-motion settings.

> A web page can only make sound while it is open. Leave Wail open (Bedside mode, plugged in) overnight,
> or add it to the Home Screen.

## Develop

```bash
npm ci
npm run dev        # local dev server
npm test           # Vitest unit tests (watch mode locally; single run when CI=true)
npm run build      # type-check + production bundle in dist/
```

## Structure

| Path | Purpose |
| --- | --- |
| `src/types.ts` | Alarm, mission, history and settings types |
| `src/schedule.ts` | Next/previous occurrence, due detection, time and repeat formatting |
| `src/engine.ts` | Ring state machine: ringing → snoozed → wake-up check → re-ring, plus stats |
| `src/missions.ts` | Seeded mission generators and checkers, shake detector |
| `src/storage.ts` | Versioned, validated local storage persistence |
| `src/sounds.ts` | Baby voice catalog |
| `src/audio.ts` | Looping player with fade-in, vibration, iOS audio unlock |
| `src/components/*` | UI: list, editor, sound picker, ringing screen, missions, nap, report, settings |
| `src/__tests__/*` | Unit tests, including a check that every sound matches `provenance.json` |
| `spec/` | Lean models of the acceptance criteria this build was checked against |

## Audio provenance

Every sound file is a real recording **downloaded from Wikimedia Commons**. None were synthesized or stubbed.
Each file's SHA-1 was checked against the Commons API, then the file was converted to mono 96 kbps MP3 so iOS
Safari can play it. `provenance.json` records the source URL, author, license and SHA-256 of each file, and
the test suite checks the bundled files against it.

| Voice | File | Author | License |
| --- | --- | --- | --- |
| Newborn | `public/sounds/newborn.mp3` | the_yura (Freesound) | CC0 1.0 |
| Hungry | `public/sounds/wanting.mp3` | natalie (pdsounds.org) | Public domain |
| Disappointed | `public/sounds/disappointed.mp3` | natalie (pdsounds.org) | Public domain |
| Dawn wail | `public/sounds/kunjappi.mp3` | Manoj Karingamadathil | [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) |

"Dawn wail" is a format conversion of
[Newborn baby crying sounds 20190831 061900.wav](https://commons.wikimedia.org/wiki/File:Newborn_baby_crying_sounds_20190831_061900.wav)
by Manoj Karingamadathil. It is redistributed under CC BY-SA 4.0, and the Settings screen credits it in the app.
