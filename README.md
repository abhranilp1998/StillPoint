# Stillpoint

A Flutter mobile app for private behavioral awareness, dependency reduction, and recovery support.

Stillpoint is intentionally neutral in tone. It avoids shame-based language and focuses on helping people understand patterns, reduce friction, and keep progress visible even when behavior changes non-linearly.

## What is implemented

- Flutter + Material 3 app shell for Android and iOS
- Riverpod state management
- Hive local storage with an AES key stored through `flutter_secure_storage`
- Ultra-fast quick logging for cigarettes, vaping, alcohol, recreational substances, caffeine, gambling, doomscrolling, pornography, prescription misuse, and custom trackers
- Drugs and pills are included as first-class default trackers
- Optional mood, craving, stress, trigger, and note context
- Home screen with today summary, quick log buttons, trend chart, mood overview, and data-backed observations
- Habit detail screens with recent logs, per-tracker charts, risk notes, cooldown guidance, trusted resources, and pattern-aware web search
- Analytics screen with weekly comparison, time-of-day chart, GitHub-style heatmaps, trigger associations, and flexible reduction modes
- Craving support screen with breathing, urge-delay timer, and grounding prompts
- History screen with search, sorting, date filtering, CSV export, XLSX export, sharing, row editing, and row clearing
- Privacy screen with local-first messaging, biometric lock, PIN lock, hidden notification content, quiet-hour controls, dark mode, and reduce-motion mode
- Branded native launch splash on Android and iOS
- Android notification and biometric permissions
- iOS Face ID usage description

## Verification

```sh
flutter analyze
flutter test
flutter build apk --debug
```

The debug APK is generated at:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

## Next production steps

- Add Supabase sync behind an explicit opt-in privacy gate
- Add scheduled adaptive reminders using timezone-aware notification scheduling
- Add larger dataset pagination benchmarks on low-end Android hardware
- Add onboarding, consent copy, and a first-run privacy walkthrough
- Add release signing, app icons, and store metadata
