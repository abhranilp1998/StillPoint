# StillPoint

A Flutter mobile app for private behavioral awareness, dependency reduction, and recovery support.

StillPoint is intentionally neutral in tone. It avoids shame-based language and focuses on helping people understand patterns, reduce friction, and keep progress visible even when behavior changes non-linearly.

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
- Sanctuary screen with steady breathing, pause timer, and grounding prompts
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

## Android release signing

StillPoint is configured to require a stable release signing key before building
release APKs or Android App Bundles. Release signing is read from the first file
that exists in this order:

1. `android/key.properties`
2. `keys/key.properties`

Use `android/key.properties` for local-only signing. Use the top-level `keys/`
folder when the signing files need to sync through your private cloud or private
repository so another machine can build the same release APK or bundle.

The `keys/` folder is intentionally not ignored by this project. That makes it
available for a private-cloud workflow, but it also means the folder must be
treated as sensitive. Keep the remote private, restrict access, and move the raw
keystore/passwords to a password manager, encrypted vault, or CI secret store
before any public/team release process.

### Synced keys folder

For a private-cloud or private-repository workflow, the real release signing
files live in the top-level `keys/` folder:

```text
keys/
  key.properties
  upload-keystore.jks
```

`keys/key.properties` contains the keystore passwords, and
`keys/upload-keystore.jks` contains the generated StillPoint upload key. Keep
both files synced only through a private cloud/private repository so another
machine can clone the repo and build the same signed release artifacts. Do not
leave these files on a public remote; make the remote private immediately if the
files are synced through Git.

If you need to recreate `key.properties`, start from the template:

```sh
cp keys/key.properties.example keys/key.properties
```

Before building on another machine, verify the cloud-synced copy contains the
same required files. The expected file is `key.properties`, not
`keys.properties`.

`keys/key.properties` should look like this:

```properties
storeFile=upload-keystore.jks
storePassword=your-keystore-password
keyAlias=upload
keyPassword=your-key-password
```

When `key.properties` is inside `keys/`, `storeFile` is resolved relative to the
`keys/` folder unless it is an absolute path. The release key alias is `upload`.

If you need to generate a new upload keystore:

```sh
keytool -genkeypair -v -keystore keys/upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Keep the generated passwords somewhere recoverable. Losing the release key can
block future updates for APK users, and losing a Play upload key requires a Play
Console reset process.

### Build release artifacts

After `keys/key.properties` and the keystore are in place:

```sh
flutter build apk --release
flutter build appbundle --release
```

Release outputs:

```text
build/app/outputs/flutter-apk/app-release.apk
build/app/outputs/bundle/release/app-release.aab
```

Verify the APK signature before sharing:

```sh
apksigner verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

If `apksigner` is not on `PATH`, use the copy under the local Android SDK
`build-tools` folder.

### New machine setup

On another machine:

```sh
flutter pub get
test -f keys/key.properties
test -f keys/upload-keystore.jks
flutter build apk --release
flutter build appbundle --release
```

If the synced `keys/` folder is present, no extra local Android signing setup is
needed. If either file check fails, wait for the cloud sync to finish or restore
the missing file from the private key backup before building.

## Next production steps

- Add Supabase sync behind an explicit opt-in privacy gate
- Add scheduled adaptive reminders using timezone-aware notification scheduling
- Add larger dataset pagination benchmarks on low-end Android hardware
- Add app icons and store metadata
- Move raw release signing material to an encrypted vault or CI secrets when the project grows beyond the current private-cloud workflow
