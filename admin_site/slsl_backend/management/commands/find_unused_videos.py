"""Find (and optionally archive) videos in the R2 bucket that no entry references.

Every Video row's `media` file lives under the `media/` prefix in the R2 bucket
(django-storages' S3 backend is configured with location="media"; see
settings.py). Re-recording a sign or deleting an entry leaves the old object in
the bucket with nothing pointing at it. This lists those orphans, and with
--archive moves each from `media/<name>` to `archive/<name>` — out of the app's
way (it only ever reads media/) but still in the bucket, so a mistaken archive
is recoverable. Nothing is deleted.

Run it from admin_site/ against prod: it needs the prod DB + R2 secrets, i.e.
prod_secrets.json present (the same footgun as the other prod scripts — that
file shadows secrets.json and points you at prod).

    uv run python manage.py find_unused_videos            # just list them
    uv run python manage.py find_unused_videos --archive  # list + move

SLSL only. Auslan has no content backend — its R2 bucket is only a fallback
mirror of scraped media — so this deliberately lives in the SLSL admin site and
must never be pointed at Auslan data.
"""

from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand, CommandError

from slsl_backend.models import Video

# Where archived orphans are moved to: a sibling of the media/ prefix. The app
# only reads media/, so moving here hides them from clients while keeping them in
# the bucket (recoverable) rather than deleting — R2 has no point-in-time
# recovery, so we never hard-delete media here.
ARCHIVE_PREFIX = "archive/"


class Command(BaseCommand):
    help = "Find R2 videos not referenced by any entry (SLSL only); --archive moves them."

    def add_arguments(self, parser):
        parser.add_argument(
            "--archive",
            action="store_true",
            help="Move each unused video from media/ to archive/ (copy then "
            "delete). Without this flag the command only lists them.",
        )

    def handle(self, *args, **options):
        storage = default_storage

        # Only meaningful against the real R2 bucket. In local dev no r2_*
        # secrets are set, so default storage is the filesystem backend (no
        # bucket, no prod data) — bail rather than report every local file as an
        # orphan.
        bucket_name = getattr(storage, "bucket_name", None)
        if not bucket_name:
            raise CommandError(
                "Default storage is not the S3/R2 backend. Run this from "
                "admin_site/ with the prod R2 + DB secrets configured "
                "(prod_secrets.json present)."
            )

        # DB side: every media path an Entry -> SubEntry -> Video points at.
        # `media` values are storage names relative to the media/ location (e.g.
        # "hello_ab12cd.mp4"), which is exactly the key space we compare against.
        referenced = {
            name for name in Video.objects.values_list("media", flat=True) if name
        }

        # Bucket side: every object actually under the media/ prefix. Paginate
        # (there are ~5000 objects) via the storage's own boto3 client so we
        # inherit its endpoint, credentials and the R2 checksum Config from
        # settings.
        location = (storage.location or "").strip("/")
        media_prefix = f"{location}/" if location else ""
        client = storage.connection.meta.client
        present = {}  # name relative to media/ -> full object key
        paginator = client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=bucket_name, Prefix=media_prefix):
            for obj in page.get("Contents", ()):
                key = obj["Key"]
                name = key[len(media_prefix) :]
                # Skip the prefix's own "folder" placeholder object, if any.
                if not name or name.endswith("/"):
                    continue
                present[name] = key

        orphans = sorted(set(present) - referenced)
        missing = sorted(referenced - set(present))

        self.stdout.write(
            f"{len(referenced)} media references in DB, "
            f"{len(present)} objects under {media_prefix!r}, "
            f"{len(orphans)} unused."
        )
        # Surface the inverse (entries pointing at objects that aren't in the
        # bucket) as a count so a bad number above isn't mistaken for healthy.
        # Fixing those is a separate concern (scripts/find_broken_links.py).
        if missing:
            self.stdout.write(
                self.style.WARNING(
                    f"(also {len(missing)} DB references with no object in the bucket)"
                )
            )

        for name in orphans:
            self.stdout.write(f"  unused: {name}")

        if not options["archive"]:
            if orphans:
                self.stdout.write(
                    "Re-run with --archive to move these to the archive/ prefix."
                )
            return

        moved = 0
        for name in orphans:
            src_key = present[name]
            dst_key = f"{ARCHIVE_PREFIX}{name}"
            try:
                # Server-side copy, then delete the original: an S3/R2 "move".
                client.copy_object(
                    Bucket=bucket_name,
                    CopySource={"Bucket": bucket_name, "Key": src_key},
                    Key=dst_key,
                )
                client.delete_object(Bucket=bucket_name, Key=src_key)
            except Exception as e:
                self.stderr.write(self.style.ERROR(f"  failed to archive {name}: {e}"))
                continue
            moved += 1
            self.stdout.write(f"  archived: {src_key} -> {dst_key}")

        self.stdout.write(
            self.style.SUCCESS(f"Archived {moved}/{len(orphans)} unused videos.")
        )
