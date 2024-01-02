# This script finds videos in the bucket that aren't referred to by any Video in the DB.
# Run this from admin_site/ with this command:
# poetry run python manage.py shell < scripts/find_unused_videos.py

from slsl_backend.models import Video
from slsl_backend.storages import MediaStorage

links = set([e["media"] for e in Video.objects.all().values("media")])

storage = MediaStorage()
videos = set([e for e in storage.listdir(".")[1] if e])

for video in videos:
    if video not in links:
        print(f"Unused video: {video}")
