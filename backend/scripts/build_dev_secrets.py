import argparse
import json
import logging

LOG = logging.getLogger(__name__)
formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
ch = logging.StreamHandler()
ch.setFormatter(formatter)
LOG.addHandler(ch)


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("-d", "--debug", action="store_true")
    parser.add_argument("server_setup_secrets_json_path")
    parser.add_argument("--out-path", default="secrets.json")
    args = parser.parse_args()
    return args


def main():
    args = parse_args()

    if args.debug:
        LOG.setLevel("DEBUG")
    else:
        LOG.setLevel("INFO")

    # Load up all the server-setup secrets.
    with open(args.server_setup_secrets_json_path, "r") as f:
        server_secrets = json.load(f)

    # Pull out the secrets specific to this project.
    secrets = server_secrets["slsl_dictionary"]

    # Change the deployment mode.
    secrets["deployment_mode"] = "dev"

    # Use a local db.
    secrets["sql_engine"] = "django.db.backends.sqlite3"
    secrets["sql_database"] = "./devdb.sqlite3"
    secrets["sql_user"] = "blah"
    secrets["sql_password"] = "blah"
    secrets["sql_host"] = "blah"
    secrets["sql_port"] = 4242

    with open(args.out_path, "w") as f:
        json.dump(secrets, f, indent=4)


if __name__ == "__main__":
    main()
