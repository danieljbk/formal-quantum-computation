# Baby Alarm (iOS)

An iOS alarm clock in which every alarm sound is a real recording of a baby
crying. You pick which baby (voice) each alarm uses. It rings in the morning,
or whenever an alarm is set.

The feature set follows the alarm apps at the top of the App Store charts.
None of their names, art or sounds are used.

## Features

| Area | What it does |
| --- | --- |
| Alarms | Several alarms, each with a time, label, on/off switch and repeat days (weekdays / weekends / every day / custom / once). A one-time alarm turns itself off after it rings. |
| Baby voices | 4 real baby-cry recordings (Newborn, Fussy, Hungry, Nursery) plus "Surprise baby", which picks a different one each day. Each voice can be previewed. |
| Quick alarm | One-tap nap timer (+1 … +90 min) that rings once and then removes itself. |
| Missions | The crying only stops after a mission: math (easy / medium / hard, 1–10 problems), shake (10–200), typing a sentence (1–5), or tapping (10–200). Or no mission at all. |
| Snooze | On/off, 1–30 min, limit of 1–10 or unlimited. Also works from the notification's Snooze action. |
| Sound | Volume, fade-in over 15–120 s, vibration. The sound is quieter while you're solving a mission. |
| Wake-up check | After you dismiss, it asks "Are you awake?" at a delay you choose. If you don't confirm within 100 s, the baby cries again. |
| Background ringing | Optional silent audio stream that keeps the app alive so the crying plays at full length. Each ring is also backed by a burst of notifications spaced 30 s apart, so it still sounds if the app is suspended. |
| Tabs | Alarms; Babies (listen to every voice, set the default for new alarms, or switch every alarm to one baby); Settings (background ringing, notification status, sound credits). |
| Next-alarm header | A countdown on the main screen ("Rings in 7 h 12 min"). |

## Sound provenance

The clips in `BabyAlarm/Resources/Sounds/` were downloaded from Wikimedia
Commons. Each download was checked against the SHA-1 that Commons publishes,
then converted to 22.05 kHz mono CAF of 29 s or less, because iOS ignores
notification sounds longer than 30 s. `sounds.json` records the source URL,
author, licence, the original's SHA-1, and the SHA-256 of the bundled clip.
The unit tests recompute each SHA-256 inside the app bundle. Licences are CC0,
public domain, and CC BY-SA 4.0 (the "Nursery" clip; its converted version is
shared under the same licence and credited in Settings).

## Limitations

- **Ringing through Silent mode and Focus.** When the app is open or kept
  alive in the background, it plays the crying itself through the
  `.playback` audio session, which ignores the Silent switch. If the app has
  been suspended, only the notification burst plays, and notifications follow
  Silent mode and Focus. A guaranteed system-level alarm needs AlarmKit
  (iOS 26+) or the Critical Alerts entitlement, and this app (targeting
  iOS 16) uses neither. Each notification sound is also capped at 30 s.
- **Force-quit.** If you force-quit the app, the background keep-alive stops.
  Only the notification burst remains.
- **System volume.** The app can't raise the device volume. Its volume slider
  only sets the level relative to the system volume.
- **Not implemented.** Photo and barcode missions, step counting, sleep
  tracking and sounds, morning weather/news briefings, and home-screen
  widgets.

## Build

```sh
brew install xcodegen
cd BabyAlarm
xcodegen generate
xcodebuild -project BabyAlarm.xcodeproj -scheme BabyAlarm \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
```

The `iOS Verify (klean)` workflow runs these steps on `macos-latest` for every
push to a `claude/klean-*` branch.
