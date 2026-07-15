import base64
import hashlib
import json
import os
import requests
import time
from google.cloud import storage
from google.cloud.exceptions import NotFound


BUCKET_NAME = os.environ["bucket_name"]
DUMP_AUTH_TOKEN = os.environ["dump_auth_token"]
CLOUD_RUN_INSTANCE_URL = os.environ["cloud_run_instance_url"]
CACHE_DURATION_SECS = int(os.environ["cache_duration_secs"])


def main(_request):
    # Fetch the data from the admin service.
    data = fetch_data()
    num_entries = len(data["data"])

    # Upload the data to GCS, but only if it actually changed (see upload_data).
    uploaded = upload_data(data)

    if not uploaded:
        return (
            f"Dump unchanged ({num_entries} entries); skipped re-uploading to "
            f"{BUCKET_NAME} so apps don't re-download identical data"
        )

    time.sleep(2)

    # Request the data through the CDN.
    requests.get("https://cdn.srilankansignlanguage.org/dump/dump.json")

    return f"Uploaded dump containing {num_entries} entries to {BUCKET_NAME} and loaded it again through the CDN"


def fetch_data():
    url = f"{CLOUD_RUN_INSTANCE_URL}/dump"
    data = requests.get(
        url, headers={"Authorization": f"Bearer {DUMP_AUTH_TOKEN}"}
    ).json()
    return data


# Make sure the cache on the file expires in sync with the function running. We
# prefer to use Cache-Control with max-age rather than Expires because GCS always
# adds a Cache-Control header to responses served to Cloud CDN, making the Expires
# header not do anything. This means if no one requests this file early in the
# CACHE_DURATION_SECS window (e.g. 30 mins), then it might only get filled into the
# cache like 15 mins through that window and therefore it'll be served for 15 mins
# into the next window, even though there is newer content.
#
# To prevent this issue from occuring, we read the file through the CDN right after
# uploading it to ensure it is cached right then.
#
# We only actually re-upload when the content has changed. Uploading to GCS bumps
# the object's Last-Modified (and generation) every time, even for byte-identical
# content, and the apps use a conditional GET (If-Modified-Since keyed on the
# object's Last-Modified) to decide whether to re-download the dump. So an
# unconditional re-upload every run forces every app to re-download the entire dump
# every ~30 mins even when nothing changed. By comparing the MD5 of the new payload
# against the stored object's MD5 and skipping the upload when they match, we leave
# Last-Modified untouched and the apps correctly get a 304 instead of a full
# download. Returns True if it uploaded, False if it skipped an unchanged dump.
def upload_data(data):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(BUCKET_NAME)
    blob = bucket.blob("dump/dump.json")

    # Serialize once; this exact string is what we hash and what we upload.
    payload = json.dumps(data)

    # GCS stores each object's MD5 as a base64 string. Compare it against the MD5
    # of the payload we're about to upload to detect a genuine content change.
    new_md5 = base64.b64encode(hashlib.md5(payload.encode("utf-8")).digest()).decode()
    try:
        blob.reload()  # populates blob.md5_hash from the object's metadata
        if blob.md5_hash == new_md5:
            return False
    except NotFound:
        # First ever upload: the object doesn't exist yet, so fall through and
        # create it.
        pass

    blob.cache_control = f"public, max-age={CACHE_DURATION_SECS}"
    blob.upload_from_string(payload, content_type="application/json")
    return True
