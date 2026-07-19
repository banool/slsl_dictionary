FROM python:3.14-slim as base

# Standard Python settings for running in a container.
ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1

WORKDIR /app

FROM base as builder

# Install uv (pinned) from the official image.
COPY --from=ghcr.io/astral-sh/uv:0.11.29 /uv /uvx /bin/

# Install deps into an in-project .venv as a separate cached layer (the project
# itself is installed below, once its source has been copied in).
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev --no-install-project

# Build the actual app and install it into the venv (--no-editable installs
# from a built wheel rather than pointing at /app, so the final image only
# needs the venv).
COPY manage.py ./
COPY README.md ./
COPY slsl_backend ./slsl_backend
RUN uv sync --frozen --no-dev --no-editable

# Now we're building up the final image.
FROM base as final

# ffprobe (part of ffmpeg) is used at upload time to reject corrupt and
# undecodable videos — see slsl_backend/validators.py.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy across files from the build into the final image. The venv already
# contains the app (installed from its wheel above).
COPY --from=builder /app/.venv ./.venv
COPY --from=builder /app/manage.py .

# Copy in the run script.
COPY run.sh .

# Collect + hash the admin's static files into the image so whitenoise can serve
# them at runtime (CompressedManifestStaticFilesStorage builds its manifest
# here). Dummy required secrets just satisfy the settings import — collectstatic
# touches no DB / network / R2. deployment_mode=prod selects the whitenoise
# manifest storage.
RUN secret_key=build sql_engine=django.db.backends.sqlite3 \
    sql_database=build sql_user=build sql_password=build sql_unix_socket=/tmp/build \
    deployment_mode=prod \
    admin_username=build admin_password=build admin_email=build@example.com \
    ./.venv/bin/python manage.py collectstatic --noinput

# Run the program.
ENTRYPOINT ["./run.sh"]
