# syntax=docker/dockerfile:1.7
# ============================================================================
# Stage 1 — Builder
# ============================================================================
FROM python:3.12-slim AS builder

COPY --from=ghcr.io/astral-sh/uv:0.5.11 /uv /bin/uv

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PROJECT_ENVIRONMENT=/opt/venv

WORKDIR /build

COPY backend/pyproject.toml backend/uv.lock ./
COPY backend/app/ ./app/
COPY backend/alembic.ini ./
COPY backend/alembic/ ./alembic/

RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-dev

# ============================================================================
# Stage 2 — Runtime
# ============================================================================
FROM python:3.12-slim AS runtime

RUN groupadd --system --gid 1000 app \
    && useradd  --system --uid 1000 --gid app --create-home app

ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONUNBUFFERED=1 \
    DATA_DIR=/data \
    PORT=8080

WORKDIR /app

COPY --from=builder --chown=app:app /opt/venv /opt/venv
COPY --from=builder --chown=app:app /build/app /app/app
COPY --from=builder --chown=app:app /build/alembic.ini /app/alembic.ini
COPY --from=builder --chown=app:app /build/alembic /app/alembic
COPY --chown=app:app data/ /data/

# Lowercase nos logos (Linux é case-sensitive; candidates.json usa lowercase)
RUN cd /data/logos/partidos && \
    for f in *.png; do \
      lower=$(echo "$f" | tr '[:upper:]' '[:lower:]'); \
      [ "$f" != "$lower" ] && mv "$f" "$lower" || true; \
    done

USER app
EXPOSE 8080

CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080}"]
