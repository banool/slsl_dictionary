FROM python:3.10-slim as base

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
    POETRY_VERSION=1.3.2

# Install Poetry.
RUN pip install "poetry==$POETRY_VERSION"

# Install deps.
COPY pyproject.toml poetry.lock ./
RUN poetry config virtualenvs.in-project true && poetry install --only=main --no-root

# Build the actual app.
COPY manage.py ./
COPY slsl_backend ./slsl_backend
RUN poetry build

# Now we're building up the final image.
FROM base as final

# Copy across files from the build into the final image.
COPY --from=builder /app/.venv ./.venv
COPY --from=builder /app/dist .

# Copy in the run script.
COPY run.sh .

# Install the wheels we just built.
RUN ./.venv/bin/pip install *.whl

# Run the program.
ENTRYPOINT ["./run.sh"]
