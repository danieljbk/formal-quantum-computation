# CradleCall

A native iOS (SwiftUI) alarm clock that wakes you with the sound of a **real crying
baby**, and keeps crying until you've really got out of bed.

It has the features you'd expect from a top "can't-snooze" alarm app, built from scratch
with its own design, name and assets:

| Area | What's there |
| --- | --- |
| Alarms | List with next-ring countdown, repeat days, labels, enable toggles, skip next ring, quick alarms (1–60 min), preview ring |
| Baby voices | 7 bundled real infant recordings ([credits](CREDITS.md)), per-alarm choice with preview, **record your own baby** or import any audio file |
| Ringing | iOS 26+: AlarmKit system alarms that ring through Silent mode/Focus with the chosen cry; older iOS: an in-app looping player kept alive in the background plus chains of crying notifications |
| Missions | Math, typing, memory tiles, shake, tap-the-target, walking (pedometer), barcode/QR scan; 4 difficulties, configurable rounds, up to 5 chained per alarm, practice mode |
| Wake-up check | Minutes after dismissal you must confirm you're awake, or the baby cries again (mission required) |
| Anti-cheat | No dismiss without missions; idle missions restart and the cry returns to full volume; system volume locked up while ringing; snooze limits; stopping the system alarm without the mission re-rings a minute later; force-quitting mid-mission re-rings; backup crying notifications; warning on app termination; logged emergency exit |
| Volume | Per-alarm volume, gradual (eased) ramp up over 15–120 s, vibration |
| Sleep | Start/stop sleep sessions (ended automatically by the alarm), manual logging, ratings, 7-night chart vs. goal, bedtime and reminder |
| Insights | On-time streaks, on-time rate, time to get up, snoozes, mission time, wake-up-check pass rate, sleep debt, 14-day wake-time chart, history |
| Morning briefing | After waking (and in the Today tab): greeting, local weather (Open-Meteo), today's calendar events, last night's sleep, next alarm, a tip for the day |

## Build and run

Requires Xcode 15 or later (Xcode 26 enables the AlarmKit path) and
[XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
cd CradleCall
xcodegen generate
open CradleCall.xcodeproj        # run the "CradleCall" scheme on an iPhone or simulator
xcodebuild -project CradleCall.xcodeproj -scheme CradleCall \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

Missions that need sensors (shake, walk, barcode) and AlarmKit need a real device. To run
on a phone, set your team in Signing & Capabilities. The time-sensitive notifications
entitlement is declared in `project.yml`.

## Layout

```
CradleCall/
├── project.yml            XcodeGen manifest (app + unit tests)
├── App/
│   ├── CradleCallApp.swift, AppModel.swift   entry point, notification delegate, coordinator
│   ├── Core/              pure, unit-tested logic: scheduling, missions, ramps, anti-cheat, insights
│   ├── Services/          AlarmKit, notifications, audio engine, voices, motion, briefing, persistence
│   ├── Views/             SwiftUI screens (tabs, editor, ringing, missions, sleep, insights, briefing, settings)
│   └── Resources/Sounds/  real baby-cry recordings (+ voice_sources.json provenance)
├── CradleCallTests/       XCTest suite
└── Tools/build_voices.py  regenerates the voices from the Donate-a-cry corpus
```
