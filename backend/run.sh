#!/bin/sh

PORT=$1
ENV=$2

echo "PORT: $PORT"
echo "ENV: $ENV"

echo "Starting..."

# Set up DB if needed.
python manage.py migrate --noinput

# Create superuser if it hasn't been done already.
python manage.py initadmin

# Collect static files for admin page.
python manage.py collectstatic -c --noinput

# Run the server.
if [ "$ENV" = "dev" ]; then
    python manage.py runserver
elif [ "$ENV" = "prod" ]; then
    # Make the tep dir for the workers to use.
    mkdir -p /tmp/slsl_workers
    gunicorn --log-file=- --workers=2 --threads=4 --reload --worker-class=gthread --worker-tmp-dir /tmp/slsl_workers --bind 0.0.0.0:$PORT --forwarded-allow-ips='*' slsl_backend.asgi:application -k uvicorn.workers.UvicornWorker
else
    echo "Invalid env: $ENV"
    exit 1
fi
