# SLSL Dictionary: Backend

## Local development setup

Install Poetry: https://python-poetry.org/docs/#installation.

Change anything relevant in `secrets.json`. This contains no actual secrets, this file is just used for development.

Run the local development server on port 8000:
```
poetry run ./run.sh 8000
```

To make migrations if you changed any models, do this:
```
poetry run python manage.py makemigrations slsl_backend
```

## Building development secrets
You only need to do this once. Build a development version of `secrets.json` by running this script (you don't need to source the env to run this):
```
python scripts/build_dev_secrets.py ~/github/server-setup/secrets/vars.json
```
