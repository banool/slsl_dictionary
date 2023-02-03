# SLSL Dictionary: Backend

## Local development setup

Install Poetry: https://python-poetry.org/docs/#installation.

First, enter the virtual environment:
```
poetry shell
```

Setup the DB:
```
python manage.py migrate
python manage.py initadmin
```

Run:
```
python manage.py runserver
```

## Building development secrets
You only need to do this once. Build a development version of `secrets.json` by running this script (you don't need to source the env to run this):
```
python scripts/build_dev_secrets.py ~/github/server-setup/secrets/vars.json
```
