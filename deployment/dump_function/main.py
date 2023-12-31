import datetime
import json
import os
import requests
from google.cloud import storage


BUCKET_NAME = os.environ["bucket_name"]
DUMP_AUTH_TOKEN = os.environ["dump_auth_token"]
CLOUD_RUN_INSTANCE_URL = os.environ["cloud_run_instance_url"]
CACHE_DURATION_SECS = int(os.environ["cache_duration_secs"])


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
    dest = "dump/dump.json"

    storage_client = storage.Client()
    bucket = storage_client.get_bucket(BUCKET_NAME)
    blob = bucket.blob(dest)

    # Calculate the expiration time.
    expiration_time = datetime.datetime.utcnow() + datetime.timedelta(
        seconds=CACHE_DURATION_SECS
    )
    formatted_expiration = expiration_time.strftime("%a, %d %b %Y %H:%M:%S GMT")

    # Set the Expires header to make sure the cache on the file expires in
    # sync with the function running. We set Expires rather than max-age
    # because `age` is only tracked from when the file is filled into the
    # cache, which might not be right when the file is made. This means if
    # the file is loaded into the cache near the end of the 30 minute "window",
    # the cache will continue to serve that for 30 minutes even though there
    # is a newer file soon after.
    blob.metadata = {"Expires": formatted_expiration}

    print(f"Uploading file to {dest} with this metadata: {blob.metadata}")

    blob.upload_from_string(json.dumps(data), content_type="application/json")
