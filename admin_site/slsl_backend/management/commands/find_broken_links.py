"""Find entries whose video points at an object that isn't in the R2 bucket.

The inverse of find_unused_videos: every Video row's `media` file should exist
under the `media/` prefix in the R2 bucket (django-storages' S3 backend, see
settings.py). A row whose object is missing is a broken link — the app will show
the entry but fail to load its video.

Run it from admin_site/ against prod (needs the prod DB + R2 secrets, i.e.
prod_secrets.json present — that file shadows secrets.json and points you at
prod):

    poetry run python manage.py find_broken_links

SLSL only. Auslan has no content backend — its R2 bucket is only a fallback
mirror of scraped media — so this deliberately lives in the SLSL admin site.
"""

from django.core.files.storage import default_storage
from django.core.management.base import BaseCommand, CommandError

from slsl_backend.models import Video


class Command(BaseCommand):
    help = "Find entries whose video is missing from the R2 bucket (SLSL only)."

    def handle(self, *args, **options):
        storage = default_storage

        # Only meaningful against the real R2 bucket. In local dev no r2_*
        # secrets are set, so default storage is the filesystem backend (no
        # bucket, no prod data) — bail rather than report every entry as broken.
        bucket_name = getattr(storage, "bucket_name", None)
        if not bucket_name:
            raise CommandError(
                "Default storage is not the S3/R2 backend. Run this from "
                "admin_site/ with the prod R2 + DB secrets configured "
                "(prod_secrets.json present)."
            )

        # DB side: every media path an Entry -> SubEntry -> Video points at.
        # `media` values are storage names relative to the media/ location.
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
        present = set()
        paginator = client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=bucket_name, Prefix=media_prefix):
            for obj in page.get("Contents", ()):
                name = obj["Key"][len(media_prefix) :]
                if not name or name.endswith("/"):
                    continue
                present.add(name)

        broken = sorted(referenced - present)

        self.stdout.write(
            f"{len(referenced)} media references in DB, "
            f"{len(present)} objects under {media_prefix!r}, "
            f"{len(broken)} broken."
        )
        for name in broken:
            self.stdout.write(f"  broken link: {name}")
