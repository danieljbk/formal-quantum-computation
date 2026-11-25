# Cry Wake

A native iOS alarm clock (Swift / SwiftUI) where the alarm is a **real recorded baby crying**.
You choose which baby; it cries at the time you set until you soothe it.

The feature set follows the top-ranked alarm apps on the App Store (multiple alarms, sound
choice, snooze rules, dismissal missions, background reliability, wake-up check, history).
The app's name, look and assets are its own.

## Features

| # | Capability | What Cry Wake does |
|---|------------|--------------------|
| 1 | Alarms | Any number of alarms: time, label, repeat days (once / weekdays / weekends / custom), on/off toggle, live "next cry in…" countdown |
| 2 | Sound | Pick one of 4 recorded baby voices (a 5th, from Wikimedia Commons, is optional and is added when the fetch script can reach it) with in-app preview; volume; optional fade-in (10–120 s); vibration; "Hear it now" test |
| 3 | Snooze | Length (off, 1–20 min) and limit (1, 3, 5, 10, unlimited); remaining snoozes shown while ringing |
| 4 | Missions | To stop the crying: math (3 difficulties), shake to rock the baby (accelerometer), type a lullaby line, pat the baby N times; 1–5 rounds |
| 5 | Rings in the background | Silent audio keep-alive (`UIBackgroundModes: audio`) so the alarm rings in-app for as long as needed; plus a burst of up to 8 local notifications per ringing time (30 s apart, each playing the baby cry) as a backup if iOS kills the app. Opening a notification still requires the mission |
| 6 | Wake-up check | After soothing, confirm "I'm awake" within 1–15 min or the baby cries again (and the morning is marked as failed) |
| 7 | Wake-up history | Every wake-up logged with snoozes, mission and wake-check result; stats: total, average snoozes, minutes to dismiss, clean streak |

## Baby voices (real recordings)

All sounds are real recordings fetched from the network by
[`tools/fetch_cry_voices.py`](tools/fetch_cry_voices.py). The script:

1. **fetch:** downloads each recording listed in [`tools/voice_sources.json`](tools/voice_sources.json)
   and checks its license against the live source page (Freesound page, Wikimedia Commons API
   including a SHA-1 check). Only CC0 1.0 and CC BY-SA 4.0 are accepted.
2. **condition:** mono 44.1 kHz, picks the loudest window of at most 25 s, applies an 80 Hz
   high-pass, loudness-normalises to −14 LUFS, and fades the ends so the clip loops cleanly.
3. **encode:** Core Audio Format (IMA4 ADPCM). This is a format iOS accepts for notification
   sounds (≤ 30 s) and that `AVAudioPlayer` plays directly.

It writes `Resources/Sounds/cry_*.caf` and `Resources/Sounds/voices.json`. That JSON file is
both the provenance log (source URL, author, license, checksums, every processing parameter)
and the catalog the app loads at runtime. To regenerate the sounds you need python3 and ffmpeg:

```sh
python3 tools/fetch_cry_voices.py
```

Credits are shown in the app's **Voices** tab and listed in `voices.json`.

## Build and test

The project is defined with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd CryWake
xcodegen generate
xcodebuild -project CryWake.xcodeproj -scheme CryWake \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

The repository's `iOS Verify (klean)` GitHub workflow does the same on `macos-latest` for every
push to a `claude/klean-*` branch. It also uploads the simulator `.app`, a launch screenshot and
playable previews of the bundled cries.

Layout:

```
Sources/App        app entry, shared services
Sources/Model      Alarm, AlarmRuntime (pure timing state machine), AlarmStore, BabyVoice, missions
Sources/Services   AlarmEngine, CryPlayer (AVFoundation), NotificationScheduler, ShakeDetector
Sources/Views      SwiftUI screens
Resources/Sounds   recorded cries + voices.json
Tests              XCTest unit tests (scheduling, snooze/wake-check state machine, missions,
                   persistence, bundled-audio checks, notification planning)
tools              sound fetch/convert pipeline
```

## Known gaps vs. the reference app

* **Silent mode and Focus:** if iOS has terminated the app, only the notification backup is
  left. Notification sounds follow the ring/silent switch and Focus settings. The in-app ring
  (the normal case while the keep-alive runs) uses the playback audio category and is not
  muted by the silent switch. iOS 26's AlarmKit would fix this but is not used yet.
* **System volume:** the app sets its own player volume but does not force the device volume up.
* **Not implemented:** photo, barcode and step-count missions; sleep sounds and sleep tracking;
  morning weather/news briefing; widgets; Apple Watch.
* **Keep-alive cost:** the silent background audio keeps the app alive but uses some battery
  overnight. iOS may still end it under memory pressure.
