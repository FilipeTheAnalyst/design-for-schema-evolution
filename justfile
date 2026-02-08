# =============================================================================
# justfile — Design for Schema Evolution (DuckDB + LocalStack)
# =============================================================================
# Install just: https://github.com/casey/just#installation
#   brew install just        (macOS)
#   cargo install just       (Rust)
#
# Usage: just <recipe>
# =============================================================================

# Default recipe: show available commands
default:
    @just --list

# ─── Setup ──────────────────────────────────────────────────────────────────

# Copy .env.example to .env (won't overwrite existing)
setup-env:
    @[ -f .env ] && echo ".env already exists — skipping" || cp .env.example .env
    @echo "Edit .env if needed (defaults are already set for LocalStack)"

# Install uv (if not already installed)
install-uv:
    @command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
    @echo "uv $(uv --version) available ✓"

# Install Python dependencies locally via uv
install:
    uv sync

# Install dbt packages
dbt-deps:
    cd transform && dbt deps --profiles-dir .

# Full local setup
setup: setup-env install-uv install dbt-deps
    @echo "Setup complete ✓"

# ─── LocalStack & DuckDB ─────────────────────────────────────────────────────

# Start LocalStack (S3 emulation)
localstack-up:
    docker compose up -d localstack
    @echo "LocalStack starting... wait ~10s for readiness"
    @sleep 10
    @echo "LocalStack ready at http://localhost:4566 ✓"

# Stop LocalStack
localstack-down:
    docker compose down localstack

# Clean DuckDB database and data
db-clean:
    rm -rf ./data/schema_evolution.duckdb ./dlt_pipelines
    @echo "Database cleaned ✓"

# ─── Docker ─────────────────────────────────────────────────────────────────

# Build Docker image
build:
    docker compose build

# ─── Extraction (dlt → DuckDB) ─────────────────────────────────────────────

# Run extraction with V1 schema (original fields)
extract:
    docker compose run --rm extract

# Run extraction with V2 schema (evolved fields: precip, wind, UV)
extract-v2:
    docker compose run --rm extract-v2

# Run extraction locally (no Docker)
extract-local version="1":
    python -m extract.open_meteo_pipeline --schema-version {{version}}

# ─── Transformation (dbt) ──────────────────────────────────────────────────

# Run all dbt models
dbt-run:
    docker compose run --rm dbt-run

# Run dbt tests
dbt-test:
    docker compose run --rm dbt-test

# Run dbt build (models + tests)
dbt-build:
    docker compose run --rm dbt-build

# Load seed data
dbt-seed:
    docker compose run --rm dbt-seed

# Generate dbt docs
dbt-docs:
    docker compose run --rm dbt-docs

# ─── Full Pipeline ─────────────────────────────────────────────────────────

# Run full pipeline: extract V1 → seed → dbt build
pipeline-v1: extract dbt-seed dbt-build
    @echo "V1 pipeline complete ✓"

# Run full pipeline: extract V2 → dbt build (demonstrates schema evolution)
pipeline-v2: extract-v2 dbt-build
    @echo "V2 pipeline complete ✓ — schema evolution applied"

# Run full demo: V1 → V2 (shows schema evolution end-to-end)
demo: pipeline-v1 pipeline-v2
    @echo "Full demo complete ✓ — V1 and V2 data loaded"

# ─── Development Helpers ───────────────────────────────────────────────────

# Open interactive DuckDB CLI
duckdb:
    duckdb ./data/schema_evolution.duckdb

# Show DuckDB stats
db-info:
    @duckdb ./data/schema_evolution.duckdb ".tables"

# Run linting
lint:
    ruff check extract/ --fix
    ruff format --check extract/

# ─── Local dbt commands (no Docker) ────────────────────────────────────────

# Run dbt locally
dbt-run-local:
    cd transform && dbt run --profiles-dir .

# Test dbt locally
dbt-test-local:
    cd transform && dbt test --profiles-dir .

# Build dbt locally (run + test)
dbt-build-local:
    cd transform && dbt build --profiles-dir .

# ─── Quality & Linting ─────────────────────────────────────────────────────

# Format Python code
fmt:
    ruff format extract/

# ─── Cleanup ────────────────────────────────────────────────────────────────

# Remove build artifacts
clean:
    rm -rf transform/target transform/dbt_packages transform/logs
    find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null || true
    @echo "Cleaned ✓"

# Stop and remove Docker containers
docker-clean:
    docker compose down --volumes --remove-orphans
    @echo "Docker cleaned ✓"
