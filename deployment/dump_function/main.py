import json
import os
import requests
import time
from google.cloud import storage


BUCKET_NAME = os.environ["bucket_name"]
DUMP_AUTH_TOKEN = os.environ["dump_auth_token"]
CLOUD_RUN_INSTANCE_URL = os.environ["cloud_run_instance_url"]
CACHE_DURATION_SECS = int(os.environ["cache_duration_secs"])


def main(_request):
    # Fetch the data from the admin service.
    data = fetch_data()
    num_entries = len(data["data"])

    # Upload the data to GCS.
    upload_data(data)

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
def upload_data(data):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(BUCKET_NAME)
    blob = bucket.blob("dump/dump.json")
    blob.cache_control = f"public, max-age={CACHE_DURATION_SECS}"
    blob.upload_from_string(json.dumps(data), content_type="application/json")
