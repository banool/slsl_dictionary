from storages.backends.gcloud import GoogleCloudStorage

from slsl_backend.secrets import secrets

StaticStorage = lambda: GoogleCloudStorage(
    bucket=secrets["admin_bucket_name"], location="static"
)
MediaStorage = lambda: GoogleCloudStorage(
    bucket=secrets["media_bucket_name"], location="media"
)
