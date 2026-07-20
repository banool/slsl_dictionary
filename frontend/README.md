# SLSL Dictionary: Frontend

## Releasing

There are two operations: **upload** a build (produces an *internal* build) and **promote** an already-uploaded build to a wider audience (beta testers, then the public). The commands are the same across all three of my apps; they wrap canonical scripts in the [appci](https://github.com/banool/appci) repo (checked out as a sibling of this repo's root, one level above `frontend/`, or point at it with `APPCI_DIR`). Run these from `frontend/`.

### 1. Upload a build (internal)

- **Automatic (both platforms).** Every push that changes the app is built and uploaded by CI (`.github/workflows/ci.yml`): a signed appbundle to the Play **internal** track (shared `app-release-android.yaml`) and an archive to the **internal** TestFlight track (shared `app-release-ios.yaml`, on a macOS runner). Nothing to run by hand.
- **Manually** (e.g. to iterate without a push): make sure `ios/secrets.env` is configured with your App Store Connect API key details, then run `./ios/upload.sh` and/or `./android/upload.sh`.
  ```
  flutter pub get
  flutter pub run flutter_launcher_icons:main
  flutter pub run flutter_native_splash:create
  ./ios/upload.sh
  ```
  `ios/upload.sh` uses `xcodebuild` with automatic signing and uploads to TestFlight via `xcrun altool`, after a version preflight against the store. No fastlane, match, or manual cert management needed. The build lands as an **internal** TestFlight build; `upload.sh` does not release it any further. `android/upload.sh` is the Android counterpart: preflight, `flutter build appbundle` (signed via `android/key.properties` → the keystore in `~/creds`), upload to the Play internal track.

### 2. Promote a build (beta → public)

Promotion takes an already-uploaded internal build and sends it wider. It always needs release notes, and it works on **both** platforms via a mandatory `--stage`.

**Locally** (both platforms at once):
```
./promote.sh --stage beta        # -> TestFlight "SLSL Testers" + Play beta track ("What to Test")
./promote.sh --stage external    # -> App Store + Play production ("What's New")
```
Pass a notes file (`./promote.sh --stage external notes.txt`) for the release notes; `--stage external` falls back to a generic default, `--stage beta` prompts you for the required "What to Test" notes. Useful flags: `--dry-run` (plan only), `--ios-only` / `--android-only`, `--yes` (skip the confirm), `--no-submit` (iOS: prepare but don't submit) / `--no-commit` (Android: prepare but don't commit), `--rollout=0.2` (Android staged rollout). Android promotion assumes the build is already on the Play internal track (from CI).

**Via GitHub Actions** (no local checkout needed, both platforms): Actions → **Promote** → *Run workflow*, then pick:
- `stage` — `external` (App Store + Play **production**) or `beta` (TestFlight "SLSL Testers" + Play **beta** track).
- `platform` — `both` (default), `ios`, or `android`.
- `notes` — release notes ("What to Test" for beta, required; "What's New" for external, blank uses a generic default).
- `rollout` — optional Android staged-rollout fraction (e.g. `0.2`); blank = 100%.
- `dry_run` — preview without changing anything.

It runs the same `promote.sh` the local flow does (iOS promotion is pure App Store Connect API calls, so it runs on an ubuntu runner).

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

This takes screenshots for both platforms on multiple devices. Upload them to both stores with:
```
python3 screenshots/upload_screenshots.py
```

This drives the App Store Connect and Google Play APIs directly (no fastlane) and supports `--ios-only`, `--android-only`, and `--dry-run`. The stores cap a listing at 10 (App Store) and 8 (Play) screenshots while the harness captures more than that, so the ordered selection lists at the top of the script choose which captures are published and in what order — edit them there to re-curate the storefronts.

Credentials:
- **App Store Connect:** the same `ios/secrets.env` that `ios/upload.sh` uses. Screenshots attach to an *editable* app version, so create the new version in App Store Connect first if one isn't already in Prepare for Submission.
- **Google Play:** the service account JSON key at `~/creds/play_slsl.json`, or set `PLAY_SERVICE_ACCOUNT_JSON_PATH`. It is the same service account CI publishes builds with (the `ANDROID_SERVICE_ACCOUNT_JSON` secret, mirrored from the same file); it needs permission to edit the store listing in the Play Console. All Play changes happen inside a single edit that is committed only at the end, so a failed run changes nothing.

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
