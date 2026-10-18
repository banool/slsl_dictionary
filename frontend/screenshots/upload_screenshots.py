#!/usr/bin/env -S uv run --script
# Empty dependency list on purpose — see take_screenshots.py. Stdlib only; the
# block is here to pin the interpreter, not to install anything.
# /// script
# requires-python = ">=3.14"
# dependencies = []
# ///
"""Upload the captured store screenshots. Thin wrapper: the implementation
lives in appci/scripts/upload_screenshots_lib.py (sibling checkout of
this repo's root, or set APPCI_DIR); this supplies SLSL's
app-specific values. Same CLI as before: --ios-only / --android-only /
--dry-run / -d."""

import os
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
APPCI = Path(
    os.environ.get("APPCI_DIR")
    or PROJECT_ROOT.parent.parent / "appci"
)
if not (APPCI / "scripts" / "upload_screenshots_lib.py").exists():
    sys.exit(
        f"error: appci checkout not found at {APPCI}. Clone "
        "https://github.com/banool/appci next to this repo's root, "
        "or set APPCI_DIR."
    )
sys.path.insert(0, str(APPCI / "scripts"))

import upload_screenshots_lib as lib  # noqa: E402

lib.configure(
    project_root=PROJECT_ROOT,
    ios_bundle_id="com.banool.slsldictionary",
    android_package_name="com.banool.slsl_dictionary",
    # Captures are taken under "en". The Play listing is en-AU only (Play
    # shows the default language everywhere). The App Store gets the same
    # shots in all three English localizations: each storefront indexes only
    # the locales it lists (Sri Lanka's is en-GB, the US's en-US), so the
    # listing carries en-GB and en-US as well as the primary en-AU.
    play_locale_map={"en": "en-AU"},
    ios_locale_map={"en": ["en-AU", "en-GB", "en-US"]},
    # The 5.5"/4.7" iPhone and older iPad sets still held pre-Hearth captures
    # from the fastlane days; drop them so older devices get the current
    # 6.9"/13" shots scaled down.
    prune_unmanaged_ios_sets=True,
    android_image_types={
        "1080x2400": ["phoneScreenshots"],
        "2560x1600": ["sevenInchScreenshots", "tenInchScreenshots"],
    },
    # The marketable subset of the captured slugs, in storefront order (the
    # stores cap listings at 10 / 8 images). The word page leads: a signer's
    # video says what the app is at a glance, where the empty search screen
    # didn't.
    app_store_shots=[
        "03-wordPage",
        "02-searchResults",
        "09-flashcardRevealed",
        "07-revisionLanding",
        "04-saveToList",
        "05-lists",
        "06-insideList",
        "01-search",
        "08-flashcardFront",
        "11-searchDark",
    ],
    play_shots=[
        "03-wordPage",
        "02-searchResults",
        "09-flashcardRevealed",
        "07-revisionLanding",
        "04-saveToList",
        "05-lists",
        "06-insideList",
        "01-search",
    ],
)

if __name__ == "__main__":
    lib.main()
