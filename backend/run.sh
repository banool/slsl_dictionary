PORT=$1

# Set up DB if needed.
python manage.py migrate --noinput

# Create superuser.
python manage.py initadmin

# Collect static files for admin page.
python manage.py collectstatic -c --noinput

# Run the server.
gunicorn --log-file=- --workers=2 --threads=4 --reload --worker-class=gthread --worker-tmp-dir /dev/shm --bind 0.0.0.0:$PORT slsl_backend.asgi:application -k uvicorn.workers.UvicornWorker
