FROM python:3.14-slim as base

# Standard Python settings for running in a container.
ENV PYTHONFAULTHANDLER=1 \
    PYTHONHASHSEED=random \
    PYTHONUNBUFFERED=1

WORKDIR /app

FROM base as builder

# Specifically pin Poetry version.
ENV PIP_DEFAULT_TIMEOUT=90 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    POETRY_VERSION=2.2.1

# Install Poetry.
RUN pip install "poetry==$POETRY_VERSION"

# Install deps.
COPY pyproject.toml poetry.lock ./
RUN poetry config virtualenvs.in-project true && poetry install --only=main --no-root

# Build the actual app.
COPY manage.py ./
COPY README.md ./
COPY slsl_backend ./slsl_backend
RUN poetry build

# Now we're building up the final image.
FROM base as final

# ffprobe (part of ffmpeg) is used at upload time to reject corrupt and
# undecodable videos — see slsl_backend/validators.py.
RUN apt-get update \
    && apt-get install -y --no-install-recommends ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy across files from the build into the final image.
COPY --from=builder /app/.venv ./.venv
COPY --from=builder /app/dist .
COPY --from=builder /app/manage.py .

# Copy in the run script and README.
COPY run.sh .

# Install the wheels we just built.
RUN ./.venv/bin/pip install *.whl

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
