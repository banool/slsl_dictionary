# SLSL Dictionary: Frontend

## Releasing

There are two operations: **upload** a build (produces an *internal* build) and **promote** an already-uploaded build to a wider audience (beta testers, then the public). The commands are the same across both dictionary apps; they wrap canonical scripts in the [dictionarylib](https://github.com/banool/dictionarylib) repo (checked out as a sibling of this repo's root, one level above `frontend/`, or point at it with `DICTIONARYLIB_DIR`). Run these from `frontend/`.

### 1. Upload a build (internal)

- **Android — automatic.** Every push that changes the app is built (signed appbundle) and uploaded to the Play **internal** track by CI (`.github/workflows/ci.yml` → the shared `app-release-android.yaml`). Nothing to run by hand.
- **iOS — manual** (no CI path). Make sure `ios/secrets.env` is configured with your App Store Connect API key details, then run:
  ```
  flutter pub get
  flutter pub run flutter_launcher_icons:main
  flutter pub run flutter_native_splash:create
  ./ios/upload.sh
  ```
  The script uses `xcodebuild` with automatic signing and uploads to TestFlight via `xcrun altool`. No fastlane, match, or manual cert management needed. The build lands as an **internal** TestFlight build; `upload.sh` does not release it any further.

### 2. Promote a build (beta → public)

Promotion takes an already-uploaded internal build and sends it wider. It always needs release notes, and it works on **both** platforms via a mandatory `--stage`.

**Locally** (both platforms at once):
```
./promote.sh --stage beta        # -> TestFlight "SLSL Testers" + Play beta track ("What to Test")
./promote.sh --stage external    # -> App Store + Play production ("What's New")
```
Pass a notes file (`./promote.sh --stage external notes.txt`) for the release notes; `--stage external` falls back to a generic default, `--stage beta` prompts you for the required "What to Test" notes. Useful flags: `--dry-run` (plan only), `--ios-only` / `--android-only`, `--yes` (skip the confirm), `--no-submit` (iOS: prepare but don't submit) / `--no-commit` (Android: prepare but don't commit), `--rollout=0.2` (Android staged rollout). Android promotion assumes the build is already on the Play internal track (from CI).

**Android via GitHub Actions** (no local checkout needed): Actions → **Promote Android** → *Run workflow*, then pick:
- `stage` — `external` (Play **production**) or `beta` (Play **beta** track).
- `notes` — release notes (blank uses a generic default).
- `mode` — `release` to commit, or `dry-run` to preview without changing anything.
- `rollout` — optional staged-rollout fraction (e.g. `0.2`); blank = 100%.

It runs the same `play_release.py` the local script does. **iOS has no GHA path** — promote iOS locally with `./promote.sh --stage <stage> --ios-only`.

## Screenshots
First, make sure you've implemented the fix in https://github.com/flutter/flutter/issues/91668 if the issue is still active. In short, make the following change to `~/homebrew/Caskroom/flutter/2.10.3/flutter/packages/integration_test/ios/Classes/IntegrationTestPlugin.m`:
```
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [[IntegrationTestPlugin instance] setupChannels:registrar.messenger];
}
```

Update: I don't believe this is necessary anymore ^.

You may also need to `flutter clean` after this.

Then run this:
```
python3 screenshots/take_screenshots.py
```

This takes screenshots for both platforms on multiple devices. You can then upload them with these commands:
```
ios/upload_screenshots.sh
```
The Apple App Store will expect that you also upload a build for this app version first. You might need to also manually upload the photos for the 2nd gen 12.9 inch iPad (just use the 5th gen pics).

For Android, you need to just go to the Google Play Console and do it manually right now.

## General dev guide
When first pulling this repo, add this to `.git/hooks/pre-commit`:
```
#!/bin/bash

./bump_version.sh
git add pubspec.yaml
```

## Localization
Run this when you change any of the files in lib/l10n:
```
flutter gen-l10n
dart fix --apply
```

## Generating entries (de)serialization code
```
flutter pub run build_runner build
```
