import json

REQUIRED = [
    "allowed_hosts",
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
]

try:
    with open("secrets.json", "r") as f:
        secrets = json.load(f)
except FileNotFoundError:
    with open("/secrets/secrets.json", "r") as f:
        secrets = json.load(f)


invalid = []
for key in REQUIRED:
    if key not in secrets:
        invalid.append(key)

if invalid:
    raise RuntimeError(f"These secrets were not set: {invalid}")
