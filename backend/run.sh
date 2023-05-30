#!/bin/bash

PORT=$1
ENV=$2
SKIP_COLLECTSTATIC=$3

set -e

if [[ "$ENV" = "prod" || "$ENV" = "dev" ]]; then
    echo "ENV: $ENV"
else
    echo "ERROR: Invalid env: $ENV"
    exit 1
fi

if [ -z "$PORT" ]; then
    echo "ERROR: No port specified"
    exit 1
else
    echo "PORT: $PORT"
fi

echo "Starting..."

if [ "$ENV" = "prod" ]; then
    # Source the venv inside the container.
    . .venv/bin/activate
fi

# Set up DB if needed.
python manage.py migrate --noinput

# Create superuser if it hasn't been done already.
python manage.py initadmin

# Collect static files for admin page.
if [ "$SKIP_COLLECTSTATIC" = "true" ]; then
    echo "Skipping collectstatic"
else
    echo "Running collectstatic"
    python manage.py collectstatic -c --noinput
fi

# Run the server.
if [ "$ENV" = "dev" ]; then
    python manage.py runserver $PORT
else
    # Make the temp dir for the workers to use.
    mkdir -p /tmp/slsl_workers
    # Run the web server.
    gunicorn --log-file=- --workers=2 --threads=2 --reload --worker-class=gthread --worker-tmp-dir /tmp/slsl_workers --bind 0.0.0.0:$PORT --timeout 60 --forwarded-allow-ips='*' slsl_backend.asgi:application -k uvicorn.workers.UvicornWorker
fi
