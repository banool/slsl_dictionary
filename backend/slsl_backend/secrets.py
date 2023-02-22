import json
import os

REQUIRED = [
    "secret_key",
    "sql_engine",
    "sql_database",
    "sql_user",
    "sql_password",
    "sql_host",
    "sql_port",
    "deployment_mode",
    "admin_username",
    "admin_password",
    "admin_email",
    "static_bucket",
    "media_bucket",
]

try:
    # Try secrets.json first.
    with open("secrets.json", "r") as f:
        secrets = json.load(f)
except FileNotFoundError:
    try:
        # Then /secrets/secrets.json.
        with open("/secrets/secrets.json", "r") as f:
            secrets = json.load(f)
    except FileNotFoundError:
        # Then just env vars.
        secrets = {}
        for secret in REQUIRED:
            value = os.environ.get(secret)
            if value is not None:
                secrets[secret] = value


invalid = []
for key in REQUIRED:
    if key not in secrets:
        invalid.append(key)

if invalid:
    raise RuntimeError(f"These secrets were not set: {invalid}")
