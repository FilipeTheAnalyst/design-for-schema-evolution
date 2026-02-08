# Setup Validation Guide

This document provides a step-by-step validation of the entire project setup. Follow these steps in order to ensure everything works end-to-end.

## Prerequisites Checklist

Before starting, verify you have the following installed:

```bash
# Python 3.10-3.13 (3.14+ has dbt compatibility issues)
python3 --version
# Expected: Python 3.10.x, 3.11.x, 3.12.x, or 3.13.x

# uv package manager
uv --version
# Expected: uv 0.x.x or higher
# If not installed: curl -LsSf https://astral.sh/uv/install.sh | sh

# Docker & Docker Compose
docker --version
docker compose --version
# Expected: Docker 20+, Docker Compose 2+

# just command runner
just --version
# Expected: just 1.x.x
# If not installed (macOS): brew install just

# git
git --version
# Expected: git 2.x.x
```

---

## Step 1: Environment Setup

### 1.1 Create `.env` file

```bash
just setup-env
# This creates .env from .env.example (won't overwrite existing)

# Verify the file was created:
cat .env
```

### 1.2 Verify `.env` with LocalStack defaults

```bash
# The .env file comes pre-configured for LocalStack:
cat .env | grep -E "DUCKDB_|AWS_"

# Expected output:
# DUCKDB_DATABASE=./data/schema_evolution.duckdb
# DUCKDB_SCHEMA=raw
# AWS_ENDPOINT_URL=http://localhost:4566
# AWS_ACCESS_KEY_ID=test
# AWS_SECRET_ACCESS_KEY=test
```

---

## Step 2: Python & Dependency Installation

### 2.1 Install Python packages

```bash
just install
# This runs: uv sync
# Installs all dependencies from pyproject.toml
```

### 2.2 Verify installed packages

```bash
uv pip list | grep -E "dlt|dbt|duckdb|boto3|requests|python-dotenv"

# Expected packages:
# - dlt
# - dbt-core
# - dbt-duckdb
# - duckdb
# - boto3
# - requests
# - python-dotenv
```

### 2.3 Install dbt packages

```bash
just dbt-deps

# Expected output shows installed packages:
# - dbt_utils
# - dbt_expectations
```

---

## Step 3: Docker & LocalStack Setup

### 3.1 Build Docker image

```bash
just build

# Expected output:
# Successfully built schema-evolution:latest
# Includes all dependencies: dlt, dbt-duckdb, duckdb, boto3, etc.
```

### 3.2 Start LocalStack (S3 emulation)

```bash
just localstack-up

# Expected output:
# LocalStack starting... wait ~10s for readiness
# LocalStack ready at http://localhost:4566 ✓
```

### 3.3 Verify LocalStack S3 bucket

```bash
# List S3 buckets via LocalStack
aws --endpoint-url=http://localhost:4566 s3 ls

# Expected output:
# 2024-02-08 12:34:56 schema-evolution-iceberg
```

---

## Step 4: dbt Validation

### 4.1 dbt compile (validates SQL without running)

```bash
cd transform && dbt compile --profiles-dir . --target dev

# Expected output:
# ✓ Compiled successfully
# (All models compile without errors)
```

### 4.2 Create data directory

```bash
mkdir -p ./data
# DuckDB will auto-create the database file here
```

---

## Step 5: Data Pipeline Validation

### 5.1 Extract V1 schema (original fields)

```bash
just extract

# Expected output:
# Pipeline load complete
# Loaded tables into DuckDB RAW schema:
#   - weather_forecasts (100-200 rows)
#   - weather_hourly (1000-2000 rows)

# Optionally verify:
just duckdb
> SELECT * FROM raw.weather_forecasts LIMIT 5;
> .quit
```

### 5.2 Run dbt models on V1 data

```bash
just dbt-build

# Expected output:
# ✓ 8 models selected
# ✓ Completed successfully
# (All tests pass)
```

### 5.3 Extract V2 schema (evolved fields)

```bash
just extract-v2

# Expected output:
# Pipeline load complete
# New columns added to DuckDB:
#   - precipitation_sum
#   - wind_speed_10m_max
#   - uv_index_max
#   - etc.
```

### 5.4 Rebuild dbt models on V2 data

```bash
just dbt-build

# Expected output:
# ✓ 8 models selected
# ✓ Completed successfully
# (All models rebuild, handling evolved schema gracefully)
```

---

## Step 6: Full End-to-End Demo

### 6.1 Run complete V1 → V2 pipeline

```bash
# Clean and restart
just db-clean

# Run V1 pipeline
just pipeline-v1
# Expected: Extract V1 → Load Seeds → Build Models

# Run V2 pipeline (schema evolved)
just pipeline-v2
# Expected: Extract V2 → Rebuild Models
# Evolved columns now have data instead of NULL
```

### 6.2 Inspect final results

```bash
just duckdb

# Verify V1 data exists:
> SELECT COUNT(*) FROM raw.weather_forecasts;

# Verify V2 evolved columns exist:
> SELECT precipitation_sum, wind_speed_10m_max, uv_index_max FROM raw.weather_forecasts LIMIT 1;

# Verify marts table:
> SELECT * FROM marts.fct_weather_summary LIMIT 5;

# Check schema versions:
> SELECT DISTINCT schema_version FROM marts.fct_weather_summary;

> .quit
```

---

## Troubleshooting

### `python3 --version` shows Python 3.14+

**Problem:** dbt has compatibility issues with Python 3.14.

**Solution:** Use Python 3.13 or earlier:
```bash
pyenv install 3.13.5
pyenv local 3.13.5
uv sync
```

### Docker build fails

**Problem:** Docker daemon not running or resource constraints.

**Solution:**
```bash
# Start Docker
open -a Docker  # macOS

# Wait 30s, then retry
just build
```

### LocalStack port 4566 already in use

**Problem:** Another process or stale container is using the port.

**Solution:**
```bash
# Stop all LocalStack containers
docker ps | grep localstack | awk '{print $1}' | xargs docker stop

# Clean and retry
just localstack-down
just localstack-up
```

### `dbt compile` fails with "Could not find profile"

**Problem:** dbt profile not found in transform/ directory.

**Solution:**
```bash
# Verify profile exists
ls -la transform/profiles.yml

# Verify environment variables
echo $DBT_PROFILES_DIR

# Try explicit target:
cd transform && dbt compile --profiles-dir . --target dev
```

### DuckDB file locked or corrupted

**Problem:** Previous process held lock or incomplete transaction.

**Solution:**
```bash
# Clean database
just db-clean

# Verify it was deleted
ls -la data/

# Restart pipeline
just pipeline-v1
```

### Extract command fails with "destination not configured"

**Problem:** dlt doesn't recognize DuckDB configuration.

**Solution:**
```bash
# Verify .env has DuckDB vars:
cat .env | grep DUCKDB_

# Try with Docker:
just extract

# Or locally (check PYTHONPATH):
cd extract && python -m extract.open_meteo_pipeline --help
```

---

## Checklist: Setup Complete

- [ ] Python 3.10-3.13 installed
- [ ] uv installed and `uv --version` works
- [ ] Docker & Docker Compose running
- [ ] .env file created with LocalStack defaults
- [ ] `just install` completed successfully
- [ ] `just dbt-deps` completed successfully
- [ ] Docker image built (`just build`)
- [ ] LocalStack started (`just localstack-up`)
- [ ] V1 extraction successful (`just extract`)
- [ ] dbt models built (`just dbt-build`)
- [ ] V2 extraction successful (`just extract-v2`)
- [ ] V2 models rebuilt successfully
- [ ] Query results show evolved columns with data
- [ ] All tests passing

**If all checked:** Your setup is complete! 🎉

---

## Next Steps

- Run the full demo: `just demo`
- Generate dbt docs: `just dbt-docs`
- Explore the data locally: `just duckdb`
- Review the transformations: `cd transform && dbt docs generate`
- Read the schema evolution guide: [docs/04_designing_for_evolution.md](docs/04_designing_for_evolution.md)
