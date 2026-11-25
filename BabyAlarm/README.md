# Baby Alarm (iOS)

An iOS alarm clock in which every alarm sound is a real recording of a baby
crying. You pick which baby (voice) each alarm uses. It rings in the morning,
or whenever an alarm is set.

The feature set follows the alarm apps at the top of the App Store charts.
None of their names, art or sounds are used.

## Tabs

| Tab | What it does |
| --- | --- |
| Alarm | Countdown to the next alarm. Alarm list with swipe actions (edit, delete, duplicate, skip the next ring) and a context menu. Floating **+** button and a quick nap alarm (+1 … +90 min). |
| Sleep | Four real sleep-sound recordings (rain, thunder, ocean, river) with a fade-out timer. Bedtime reminder. Overnight tracking that records the room, detects snoring and sleep-talk events, and plays them back. Past nights. |
| Morning | Briefing with local weather (Open-Meteo), quote of the day, a just-for-fun daily fortune, last night's sleep and today's alarms. It also opens automatically after you dismiss an alarm. |
| Record | Current and best streak, average time to get up, average snoozes and on-time rate. Week and month charts of time-to-get-up and hours slept. Full wake-up history. |
| Settings | Theme, baby voice gallery (preview, default voice, apply to all alarms), default missions, briefing options, system-alarm status, background ringing, a permissions checklist, and credits for every recording. |

## Alarms

| Area | What it does |
| --- | --- |
| Schedule | Time, label, repeat days (weekdays, weekends, every day, custom, once) and skip-next. A one-time alarm turns itself off after it rings. |
| Baby voices | 4 real baby-cry recordings, plus "Surprise baby", which picks a different one each day. |
| Cry escalation | Optional. Every 45 s a more upset baby takes over (fussing → crying → wailing), on top of a 15–120 s fade-in. |
| Missions | A chain of up to 5 missions that must all be finished before the crying stops: **Math** (3 levels), **Typing**, **Memory** (3 levels), **Shake**, **Steps** (pedometer), **Squats** (motion), **Photo** (match a registered spot with Vision), **Barcode / QR** (scan a registered code), and Tap. |
| Snooze | Length 1–30 min, limit 1–10 or unlimited. Also available from the notification. |
| Wake-up check | After you dismiss, it asks "Are you awake?" at a delay you choose. If you don't confirm within 100 s, the baby cries again. |
| Reliability | On iOS 26+ each upcoming ring is also an **AlarmKit system alarm**: it rings through Silent mode and Focus even if the app was force-quit, and "Calm the baby" opens the missions. On every iOS version the app also runs a background keep-alive and backs each ring with a burst of 30 s notifications. If a clip fails to load, it falls back to the default baby, then to the system alert tone. |

## Sound provenance

Every sound is a real recording from Wikimedia Commons. Each download was
checked against the SHA-1 that Commons publishes.

- Baby cries (`Resources/Sounds/`, recorded in `sounds.json`) are 22.05 kHz
  mono CAF of 29 s or less, because iOS ignores notification sounds longer
  than 30 s. Licences are CC0, public domain, and CC BY-SA 4.0 (the "Nursery"
  clip; its converted version is shared under the same licence).
- Sleep sounds (`Resources/SleepSounds/`, recorded in `sleep_sounds.json`)
  are AAC loops of up to 180 s, all public domain or CC0.

Each manifest records the source URL, author, licence, the original's SHA-1
and the SHA-256 of the bundled file. The host-app tests recompute every
SHA-256. All recordings are credited in Settings.

## Limitations

- **iOS 16–25.** AlarmKit only exists on iOS 26 and later. On older versions,
  a suspended app can only ring through notifications, which follow Silent
  mode and Focus and are capped at 30 s each.
- **System volume.** The app can't raise the device volume. Its volume slider
  only sets the level relative to the system volume.
- **Toddler voice.** Commons has no openly licensed toddler-tantrum recording,
  so there is no toddler voice. Escalation uses the four baby recordings.
- **Power-off and uninstall guards.** Some Android alarm apps block these.
  iOS doesn't allow it.
- **Not implemented.** Home-screen widgets, Live Activity countdown, cloud
  backup, and any paid tier.
- **Hardware checks in CI.** The simulator has no camera, pedometer or motion
  sensor. The mission logic is unit-tested, and on such devices the missions
  fall back to tapping.

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
