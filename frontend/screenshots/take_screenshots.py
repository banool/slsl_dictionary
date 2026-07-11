#!/usr/bin/env python3
"""Generate the store screenshots. Thin wrapper: the implementation lives in
dictionarylib/scripts/take_screenshots_lib.py (sibling checkout of this
repo's root, or set DICTIONARYLIB_DIR); this supplies SLSL's app-specific
values. Same CLI as before: --ios-only / --android-only /
--clear-screenshots / -d."""

import json
import os
import sys
import urllib.request
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DICTIONARYLIB = Path(
    os.environ.get("DICTIONARYLIB_DIR")
    or PROJECT_ROOT.parent.parent / "dictionarylib"
)
if not (DICTIONARYLIB / "scripts" / "take_screenshots_lib.py").exists():
    sys.exit(
        f"error: dictionarylib checkout not found at {DICTIONARYLIB}. Clone "
        "https://github.com/banool/dictionarylib next to this repo's root, "
        "or set DICTIONARYLIB_DIR."
    )
sys.path.insert(0, str(DICTIONARYLIB / "scripts"))

import take_screenshots_lib as lib  # noqa: E402

# Must match the words the shared screenshot suite seeds into the Animals
# list for this app (integration_test/test_config.dart) plus the entry the
# word page opens ("Sri Lanka"), so every video-bearing capture has a poster.
SEEDED_WORDS = [
    "bear",
    "fish",
    "rabbit",
    "elephant",
    "tiger",
    "wolf",
    "Sri Lanka",
]

# SLSL ships no local data file — the dictionary is downloaded at runtime. The
# poster step fetches the same dump the app reads and resolves each video
# filename ("0.mp4") to its media URL ("<base>/media/0.mp4"), matching
# MySubEntry.getMedia (frontend/lib/entries_types.dart). The direct GCS bucket
# is used over the CDN for reliability; the poster name only depends on the
# trailing "/media/<file>", which both bases share.
MEDIA_BASE = "https://storage.googleapis.com/slsl-media-bucket-d7f91f9"
DATA_DUMP_URL = f"{MEDIA_BASE}/dump/dump.json"


def poster_video_urls():
    """Video URLs for the seeded words, resolved from the runtime dump."""
    with urllib.request.urlopen(DATA_DUMP_URL) as resp:
        data = json.loads(resp.read())
    urls = []
    for entry in data["data"]:
        if entry.get("word_in_english") not in SEEDED_WORDS:
            continue
        for sub in entry.get("sub_entries") or []:
            for video in sub.get("videos") or []:
                urls.append(f"{MEDIA_BASE}/media/{video}")
    return urls


lib.configure(
    project_root=PROJECT_ROOT,
    locale_dir="en",
    # Required formats first, the optional standard-size iPhone last, so a
    # flaky optional device can never block capturing the formats the stores
    # require.
    ios_targets=[
        ("iPhone 17 Pro Max",
         "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max"),         # 6.9" (required)
        ("iPad Pro 13-inch (M5)",
         "com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB"),  # 13" (required for iPad)
        ("iPhone 17",
         "com.apple.CoreSimulator.SimDeviceType.iPhone-17"),                 # 6.3" (standard, optional)
    ],
    android_targets=[
        ("AD_phone", "pixel_7"),        # phone (required)
        ("AD_tablet", "pixel_tablet"),  # ~11" tablet (covers the 10" slot)
    ],
    poster_video_urls=poster_video_urls,
)

if __name__ == "__main__":
    lib.main()
