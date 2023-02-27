# This script finds entries where there is a video link that doesn't point to an actual
# video in the bucket. Run this from backend/ with this command:
# poetry run python manage.py shell < scripts/find_broken_links.py

from slsl_backend.models import Video
from slsl_backend.storages import MediaStorage

links = set([e["media"] for e in Video.objects.all().values("media")])

storage = MediaStorage()
actual_videos = set([e for e in storage.listdir(".")[1] if e])

for link in links:
    if link not in actual_videos:
        print(f"Broken link: {link}")
