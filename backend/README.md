# SLSL Dictionary: Backend

## Local development
Install Poetry: https://python-poetry.org/docs/#installation.

Change anything relevant in `secrets.json`. This contains no actual secrets, this file is just used for development.

Run the local development server on port 8000:
```
poetry run ./run.sh 8080 dev
```

To make migrations if you changed any models, do this:
```
poetry run python manage.py makemigrations slsl_backend
poetry run python manage.py makemigrations
```

## Running locally with the prod DB
It is possible to run the app locally while connecting to the production database. This can be handy for running migrations, writing to the DB without going through Cloud Run, uploading media content, etc. Notably it's not so good for uploading data to the buckets, because we don't have credentials for that.

First, run the Cloud SQL proxy:
```
cloud-sql-proxy slsl-dictionary:asia-south1:slsl-db-instance-04a74a9 --port 5433
```

Next, make a file called `prod_secrets.json` where the following keys are different from `secrets.json`:
```
"deployment_mode": "dev",
"sql_engine": "django.db.backends.postgresql",
"sql_database": <sql_database>,
"sql_host": "127.0.0.1",
"sql_port": "5433",
"sql_user": <sql_user>,
"admin_username": <admin_username>,
"admin_password": <admin_password>
```

For the secrets:
- `sql_database`: Find the database name here: https://console.cloud.google.com/sql/instances/slsl-db-instance-04a74a9/databases?project=slsl-dictionary
- `sql_user`: `pulumi config get sql_user` (from within `deployment/`)
- `sql_password`, `admin_username`, `admin_password`: Same as with `sql_user`
- `bucket_name`: Find the bucket name here: https://console.cloud.google.com/storage/browser?project=slsl-dictionary

Then in run.sh comment out the `collectstatic` line, it doesn't work right now when running in this setup.

Finally, run the server locally like this:
```
poetry run ./run.sh 8080 dev
```
