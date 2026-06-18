"""Upload-time validation for the Video.media field.

Two failure modes have shipped to users in the past, both rendering as a blank
(blue) rectangle in the apps:

  * Corrupt / truncated uploads (e.g. a 48-byte .mp4 with no moov atom).
  * Videos encoded in a format consumer decoders can't read. iOS VideoToolbox,
    Android MediaCodec and the web build's HTML5 <video> only decode 8-bit
    4:2:0 H.264. Pro/editing exports — H.264 High 4:2:2 10-bit (yuv422p10le),
    4:4:4, etc. — load fine but never render.

These run at upload time so a bad file is rejected before it reaches users.
Validation needs `ffprobe` (shipped in the Docker image); if it's missing
(e.g. a bare local dev box) the check is skipped with a warning rather than
blocking uploads.
"""

import json
import logging
import os
import shutil
import subprocess
import tempfile

from django.conf import settings
from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import UploadedFile

logger = logging.getLogger(__name__)

# Pixel formats consumer players can actually decode (8-bit 4:2:0).
ALLOWED_PIX_FMTS = {"yuv420p", "yuvj420p"}

IMAGE_EXTS = (".jpg", ".jpeg", ".png", ".gif", ".webp")
VIDEO_EXTS = (".mp4", ".mov", ".m4v")

_FFMPEG_HINT = (
    "ffmpeg -i in.mp4 -c:v libx264 -profile:v high -pix_fmt yuv420p -crf 20 "
    "-movflags +faststart out.mp4"
)


def check_video_path(path):
    """Raise ValidationError if the video at ``path`` is corrupt or undecodable.

    Pure (path in, exception out) so it's unit-testable without Django/uploads.
    No-op when ffprobe isn't installed.
    """
    ffprobe = shutil.which("ffprobe")
    if not ffprobe:
        logger.warning("ffprobe not found; skipping codec validation for %s", path)
        return

    proc = subprocess.run(
        [
            ffprobe,
            "-v",
            "error",
            "-select_streams",
            "v:0",
            "-show_entries",
            "stream=codec_name,pix_fmt",
            "-of",
            "json",
            path,
        ],
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise ValidationError(
            "This video is corrupt or unreadable (ffprobe could not parse it). "
            "Re-export it and upload again."
        )
    try:
        streams = json.loads(proc.stdout or "{}").get("streams", [])
    except json.JSONDecodeError:
        streams = []
    if not streams:
        raise ValidationError(
            "This file has no decodable video stream — it's likely a corrupt or "
            "truncated upload."
        )

    pix_fmt = streams[0].get("pix_fmt")
    if pix_fmt not in ALLOWED_PIX_FMTS:
        raise ValidationError(
            f"This video is encoded as '{pix_fmt}', which phones and browsers can't "
            f"decode — it would show as a blank rectangle in the app. Re-encode it to "
            f"8-bit 4:2:0 H.264 first, e.g.: {_FFMPEG_HINT}"
        )


def validate_media(value):
    """Django validator for Video.media. Validates only freshly uploaded videos;
    images and already-stored files pass through untouched."""
    # Off in local dev (see settings.VALIDATE_UPLOADED_MEDIA): the bucket's media
    # files aren't on the local disk, and the `getattr(value, "file")` probe
    # below would open an existing stored file — raising FileNotFoundError when
    # it isn't there. Skipping early avoids that and lets admins save entries.
    if not getattr(settings, "VALIDATE_UPLOADED_MEDIA", True):
        return
    name = (getattr(value, "name", "") or "").lower()
    if name.endswith(IMAGE_EXTS):
        return
    if not name.endswith(VIDEO_EXTS):
        return  # FileExtensionValidator already constrains the allowed extensions.

    upload = getattr(value, "file", None)
    if not isinstance(upload, UploadedFile):
        return  # not a new upload (unchanged existing record) — nothing to re-check.

    # TemporaryUploadedFile is already on disk; probe it in place. Otherwise
    # (small InMemoryUploadedFile) spill it to a temp file for ffprobe.
    temp_path = getattr(upload, "temporary_file_path", None)
    if callable(temp_path):
        check_video_path(temp_path())
        return

    tmp = tempfile.NamedTemporaryFile(suffix=".mp4", delete=False)
    try:
        upload.seek(0)
        for chunk in upload.chunks():
            tmp.write(chunk)
        tmp.flush()
        tmp.close()
        upload.seek(0)
        check_video_path(tmp.name)
    finally:
        os.unlink(tmp.name)
