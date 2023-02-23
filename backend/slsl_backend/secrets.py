import json
import os

REQUIRED = [
    "secret_key",
    "sql_engine",
    "sql_database",
    "sql_user",
    "sql_password",
    "deployment_mode",
    "admin_username",
    "admin_password",
    "admin_email",
]

OTHER = [
    "sql_host",
    "sql_port",
    "sql_unix_socket",
    "bucket_name",
    "additional_allowed_hosts",
    "dump_auth_token",
]

POSSIBLE_FILENAMES = ["/secrets/secrets.json", "prod_secrets.json", "secrets.json"]

secrets = {}
for fname in POSSIBLE_FILENAMES:
    if os.path.exists(fname):
        with open(fname, "r") as f:
            secrets = json.load(f)
        break

if not secrets:
    for secret in REQUIRED + OTHER:
        value = os.environ.get(secret)
        if value is not None:
            secrets[secret] = value

invalid = []
for key in REQUIRED:
    if key not in secrets:
        invalid.append(key)

if "sql_unix_socket" in secrets:
    if "sql_host" in secrets or "sql_port" in secrets:
        raise RuntimeError(
            "You can't set both a unix socket and a host/port for the DB connection"
        )

if "sql_host" in secrets and "sql_port" not in secrets:
    raise RuntimeError("You must set both a host and a port for the DB connection")

if not ("sql_unix_socket" in secrets or "sql_host" in secrets):
    raise RuntimeError(
        "You must set a unix socket or a host/port for the DB connection"
    )


if invalid:
    raise RuntimeError(f"These secrets were not set: {invalid}")
