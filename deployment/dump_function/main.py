import json
import os
import requests
from google.cloud import storage


BUCKET_NAME = os.environ["bucket_name"]
DUMP_AUTH_TOKEN = os.environ["dump_auth_token"]
CLOUD_RUN_INSTANCE_URL = os.environ["cloud_run_instance_url"]
CACHE_DURATION_SECS = os.environ["cache_duration_secs"]


def main(_request):
    data = fetch_data()
    num_entries = len(data["data"])
    upload_data(data)
    return f"Uploaded dump containing {num_entries} entries to {BUCKET_NAME}"


def fetch_data():
    url = f"{CLOUD_RUN_INSTANCE_URL}/dump"
    data = requests.get(
        url, headers={"Authorization": f"Bearer {DUMP_AUTH_TOKEN}"}
    ).json()
    return data


def upload_data(data):
    storage_client = storage.Client()
    bucket = storage_client.get_bucket(BUCKET_NAME)
    blob = bucket.blob("dump/dump.json")
    # Make sure the cache on the file expires in sync with the function running.
    blob.cache_control = f"public, max-age={CACHE_DURATION_SECS}"
    blob.upload_from_string(json.dumps(data), content_type="application/json")
