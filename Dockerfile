# =============================================================================
# Dockerfile — Design for Schema Evolution
# =============================================================================
# Multi-stage build for a reproducible dlt + dbt pipeline environment.
# =============================================================================

FROM python:3.11-slim AS base

# Prevent Python from writing .pyc files and enable unbuffered output
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy

WORKDIR /app

# Ensure the venv uv creates is on PATH
ENV PATH="/app/.venv/bin:$PATH"

# System dependencies + uv + aws-cli
RUN apt-get update && \
    apt-get install -y --no-install-recommends git curl awscli && \
    rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# ---------------------------------------------------------------------------
# Dependencies layer (cached unless pyproject.toml / uv.lock change)
# ---------------------------------------------------------------------------
FROM base AS deps

COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen --no-cache

# ---------------------------------------------------------------------------
# Application layer
# ---------------------------------------------------------------------------
FROM deps AS app

# Copy project files
COPY . .

# Install dbt packages
RUN cd transform && dbt deps --profiles-dir .

# Default: show help
CMD ["python", "-m", "extract.open_meteo_pipeline", "--help"]
