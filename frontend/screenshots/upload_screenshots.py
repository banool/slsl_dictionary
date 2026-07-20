#!/usr/bin/env python3
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
    # Captures are taken under "en", but both of SLSL's store listings (App
    # Store and Play) are en-AU.
    play_locale_map={"en": "en-AU"},
    ios_locale_map={"en": "en-AU"},
    android_image_types={
        "1080x2400": ["phoneScreenshots"],
        "2560x1600": ["sevenInchScreenshots", "tenInchScreenshots"],
    },
    # The marketable subset of the captured slugs, in storefront order (the
    # stores cap listings at 10 / 8 images).
    app_store_shots=[
        "01-search",
        "02-searchResults",
        "03-wordPage",
        "04-saveToList",
        "05-lists",
        "06-insideList",
        "07-revisionLanding",
        "08-flashcardFront",
        "09-flashcardRevealed",
        "11-searchDark",
    ],
    play_shots=[
        "01-search",
        "02-searchResults",
        "03-wordPage",
        "04-saveToList",
        "05-lists",
        "06-insideList",
        "08-flashcardFront",
        "09-flashcardRevealed",
    ],
)

if __name__ == "__main__":
    lib.main()
