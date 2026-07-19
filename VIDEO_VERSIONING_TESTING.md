# Per-video versioning — local testing guide

This describes the new "mark a video as Current / Historical, with structured dates + source + a free-text note" feature, and how to run the backend locally and the app against it. **Nothing here has been committed, pushed, or applied to prod** — it's all local working-tree changes.

## What changed

**Backend (`admin_site/slsl_backend/`)**
- `models.py` — new `VideoStatus` text-choices (`CURRENT` / `HISTORICAL`, deliberately an *open* set) and five new fields on `Video`: `status` (default `CURRENT`), `researched`, `recorded`, `published` (free-form date strings), `source`, and `note` (multiline). All optional except `status`.
- `migrations/0020_video_note_...py` — adds those fields.
- `admin.py` — the per-video inline now lays the fields out as a stacked form: status dropdown, the three dates on one row, then source and note.
- `dump.py` — `dump_video()` serialises each video. A `CURRENT` video with **no** metadata is still emitted as a bare filename string (back-compat: old app builds keep working). Anything else — `HISTORICAL`, **or a `CURRENT` video that has any metadata** — is emitted as an object `{"video", "status", ...only the non-empty fields}`. Videos are ordered newest-first (highest id first); the app trusts that order (index 0 = current) and does not re-sort.

**Frontend**
- `slsl_dictionary/frontend/lib/entries_types.dart` — `videos` is now `List<dynamic>` (string-or-object); `getMedia()` still returns the same `/media/<file>` **paths** (saved-video identity is unchanged, so existing saves keep resolving); new `getMediaItems()` returns `MediaItem`s carrying the status + metadata.
- `dictionarylib/lib/entry_types.dart` — the shared `MediaItem` type + a default `getMediaItems()` (no status → no pill, so Auslan is unaffected).
- `dictionarylib/lib/theme.dart` — a `historicalContainer` / `onHistoricalContainer` tint pair (light + dark) surfaced via a `HearthColors` theme extension (registered on both the Hearth and Classic variants).
- `dictionarylib/lib/page_word.dart` — the status pill overlaid top-left on the current carousel video, and the "source & date" bottom sheet it opens.
- `dictionarylib/lib/l10n/app_en.arb` (+ `app_si.arb`, `app_ta.arb`, regenerated) — the pill labels, sheet title, and field labels, in English, Sinhala, and Tamil.
- `slsl_dictionary/frontend/lib/main.dart` — a debug-only `DEBUG_BACKEND_BASE_URL` dart-define (a testing aid, ignored in release builds) that points the **dump fetch** at a local backend (media still resolves from the CDN). See step 2, Option B.
- `slsl_dictionary/frontend/lib/entries_loader.dart` — fixed the version fallback for a dump response with no `Last-Modified` header (the local dev backend's case): it now uses the current time directly instead of feeding an epoch-millis string to `HttpDate.parse` (which threw `Invalid HTTP date`).

> A current sign can carry the full metadata set just like a historical one. The only differences are cosmetic: a current video's sheet is titled "Current sign" (a historical one is titled e.g. "2015 version", derived from its recorded year), and a current video with *no* metadata simply shows no extra rows (and isn't worth tapping).

## Prerequisites (one-time sanity checks)

- **Tooling**: uv (backend) and Flutter (the apps). A booted iOS simulator (`xcrun simctl list devices booted`) for the on-device steps.
- **Dev secrets**: the backend's dev secrets file is `admin_site/secrets.json` — it's committed, contains no real secrets, and configures the local SQLite DB + the `admin` / `password` superuser. Nothing to create; it's used automatically (see the `prod_secrets.json` caveat in step 1).
- **dictionarylib override (so the app sees the feature)**: this feature's UI lives in `dictionarylib`, which is uncommitted. The app only builds against your local working copy if the override is active. It already is — `slsl_dictionary/frontend/pubspec_overrides.yaml` contains:
  ```yaml
  dependency_overrides:
    dictionarylib:
      path: ../../dictionarylib
  ```
  (The `git: ref:` in `frontend/pubspec.yaml` points at an older commit, but the override wins. If you ever delete the override file, `flutter run`/`flutter test` would build against that old ref and the feature would vanish.)

## 1. Run the backend locally (SQLite dev DB)

```bash
cd admin_site
```

**Important:** `prod_secrets.json` (left over from the paused prod-DB work) shadows `secrets.json` and points Django at the prod Cloud SQL instance. Move it aside so dev uses the local SQLite DB, and put it back when you're done:

```bash
mv prod_secrets.json prod_secrets.json.bak     # use local SQLite dev DB
uv run ./run.sh 8080 dev                    # migrate + create admin + runserver
# ... when finished testing ...
mv prod_secrets.json.bak prod_secrets.json      # restore the prod-DB config
```

`run.sh ... dev` runs migrations (incl. `0020`), creates the superuser **`admin` / `password`**, and serves on `http://127.0.0.1:8080`.

The dev DB already has a ready-made demo entry, **"ZZZ Versioning Demo"**: a current video (the sign for "after") and an older historical video carrying full metadata (the sign for "lorry"). Both reference **real filenames from the dataset**, so they actually play when media resolves from the prod CDN (see Option B) — handy for testing the pill/sheet on real video.

### Set metadata in the admin
Open `http://127.0.0.1:8080/admin/`, log in as `admin` / `password`, open (or create) an **Entry → sub-entry → Video**. Each video now has: **Status** (Current / Historical), **Researched / Recorded / Published** (free text — a year or a phrase is fine), **Source**, and **Note** (multiline). Upload an `.mp4` if you want playback. Save.

### Inspect the dump
```bash
curl -s http://127.0.0.1:8080/dump | python3 -m json.tool | less
```
A versioned sub-entry's `videos` looks like:
```jsonc
"videos": [
  "current_demo.mp4",                       // current, no metadata -> bare string
  {                                         // historical (or current-with-metadata) -> object
    "video": "historical_demo.mp4",
    "status": "HISTORICAL",
    "researched": "2014",
    "recorded": "2015",
    "published": "March 2016",
    "source": "Deaf School Archive, Kandy",
    "note": "Retained for documentation and research."
  }
]
```

## 2. See it in the app

### Option A — the integration test (fastest, deterministic, no backend needed)
`integration_test/video_versioning_test.dart` injects a synthetic entry (current-bare, historical-with-metadata, and current-with-metadata) and asserts the pill + sheet render and behave. It runs on a booted simulator:

```bash
cd frontend
flutter test integration_test/video_versioning_test.dart -d <booted-sim-udid>
```

> Two simulator quirks I hit while verifying (both cosmetic, not failures): if the iOS "Apple Account Verification" system dialog pops over the app it backgrounds it and stalls the run — tap **Not Now** and re-run. And like the repo's other video-bearing integration tests (see the note in `screenshot_test.dart`), the live `media_kit` player can make the run hang at *teardown* after the assertions have already passed.

### Option B — the real app against your local backend
No code edit needed. `main.dart` reads a debug-only `DEBUG_BACKEND_BASE_URL` dart-define (honoured in debug builds, ignored in release); when set it fetches the **dump** from `<base>/dump`. **Media is not redirected** — it keeps resolving from the prod CDN (the local dev backend doesn't serve media, and this way real video filenames in your data actually play). Just pass your local backend's base URL:

```bash
cd frontend
flutter run -d <booted-sim-udid> \
  --dart-define=DEBUG_BACKEND_BASE_URL=http://127.0.0.1:8080
```

You'll see `DEBUG_BACKEND_BASE_URL set: fetching the dump from ... (media still resolves from the prod CDN)` in the console. Search for **ZZZ Versioning Demo** (or whatever you set up) and swipe the video carousel — the **Current** / **Historical** pill sits at the video's top-left and updates per video; tap it for the source sheet. The demo videos ("after" / "lorry") play from the CDN.

> Because media comes from the CDN, the videos in your local data must reference **real filenames that exist in the bucket** to play (the demo entry does). A brand-new video you upload to the local admin won't play, since the local backend serves no media — that's a limitation of local dev, not this feature.

On the **iOS simulator only**, the cleartext-HTTP dump fetch from localhost is blocked by App Transport Security, so if the dictionary won't load add a temporary ATS exception to `frontend/ios/Runner/Info.plist` (revert it after) — Android needs nothing:
```xml
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsLocalNetworking</key><true/></dict>
```

## 3. Check Auslan is unaffected
Auslan shares `dictionarylib` but has no video versioning, so it must never show the pill. Its `getMediaItems()` attaches no status, and the pill is gated on that. A fast headless guard test (no simulator needed):
```bash
cd ../auslan_dictionary      # i.e. ~/github/auslan_dictionary
flutter test test/no_video_status_test.dart
```

## 4. Verifying it's all clean
`flutter analyze` is clean (no new issues) in all three repos:
```bash
(cd ~/github/dictionarylib && flutter analyze)
(cd ~/github/slsl_dictionary/frontend && flutter analyze)
(cd ~/github/auslan_dictionary && flutter analyze)
```
The backend dump output, the admin form, the SLSL app rendering, and Auslan-shows-no-pill were all verified locally before handover.

## Still to do
- Sinhala + Tamil translations of the new strings are **done** (`dictionarylib/lib/l10n/app_si.arb`, `app_ta.arb`, regenerated). They're my best effort and worth a quick native-speaker review (folds into the existing si/ta review pass) — pill labels `වර්තමාන`/`ඓතිහාසික` and `தற்போதைய`/`வரலாற்று`, etc.
- The regression test `integration_test/video_versioning_test.dart` is **kept**.
- Commit / push / deploy (backend migration + dump function, frontend) when you're happy — not done yet, by request.
