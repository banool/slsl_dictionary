# SLSL Dictionary

This repo contains all the code for SLSL Dictionary, the free forever video dictionary and revision tool for Sri Lankan Sign Language. Every entry is shown in English, Sinhala, and Tamil, and the app runs on iOS, Android, and the web.

The app is a sibling of [Auslan Dictionary](https://github.com/banool/auslan_dictionary): both are built on the shared [`dictionarylib`](https://github.com/banool/dictionarylib) Flutter package and the same shared-lists backend (a private repo, `dictionary_backend`, running on Cloudflare Workers + R2). So most feature work — search, per-video saving, shared lists, sign-in, flashcards, theming — lives in `dictionarylib` and is consumed here with SLSL-specific configuration.

## Where things live

- **`frontend/`** — the Flutter app (iOS, Android, web). This is where most day-to-day work happens; see [`frontend/README.md`](frontend/README.md) for building, deploying, and taking screenshots.
- **`site/`** — the public info + legal site (privacy policy, terms), deployed to Cloudflare Pages at [landing.srilankansignlanguage.org](https://landing.srilankansignlanguage.org). See [`site/README.md`](site/README.md).
- **`admin_site/`** — the content-management admin site used to curate dictionary entries and their videos.
- **`deployment/`** — infrastructure-as-code (TypeScript) for the data dump function, the admin site's Cloud Run service, and related Google Cloud resources.

## Hosting

- **Web app:** [app.srilankansignlanguage.org](https://app.srilankansignlanguage.org) (Cloudflare Pages).
- **Info / legal site:** [landing.srilankansignlanguage.org](https://landing.srilankansignlanguage.org) (Cloudflare Pages).
- **Shared-lists API:** `api.srilankansignlanguage.org` and `share.srilankansignlanguage.org` (the `dictionary_backend` Cloudflare Worker).

DNS for `srilankansignlanguage.org` is managed in Cloudflare; the apex hosts the wider organisation's site, which is why the dictionary's web app and info site live on subdomains.

## The three content languages

English is the canonical language: an entry's stable key is always its English phrase, and saved videos and shared lists are keyed by it. Sinhala and Tamil are display translations layered on top. Never key saved or shared data by Sinhala or Tamil — see `frontend/lib/common.dart` and the entry types in `frontend/lib/entries_types.dart`.

## Development

Start in [`frontend/README.md`](frontend/README.md) — it covers building the app, deploying to the stores and the web, and the screenshot tooling.

All Dart is formatted with `dart format`; CI enforces it. Install the git hooks once after cloning so the same check (and an automatic build-number bump) runs before each commit:

```sh
git config core.hooksPath .githooks
```
