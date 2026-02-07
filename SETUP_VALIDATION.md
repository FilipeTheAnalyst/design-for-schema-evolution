# Setup Validation Guide

This document provides a step-by-step validation of the entire project setup. Follow these steps in order to ensure everything works end-to-end.

## Prerequisites Checklist

Before starting, verify you have the following installed:

```bash
# Python 3.10+
python --version
# Expected: Python 3.10.x or higher

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
```

### 1.2 Edit `.env` with Snowflake credentials

```bash
# Open .env and fill in:
# - SNOWFLAKE_ACCOUNT: Your account identifier (e.g., abc12345.us-east-1)
# - SNOWFLAKE_USER: Your Snowflake username
# - SNOWFLAKE_PASSWORD: Your Snowflake password
# - SNOWFLAKE_ROLE: User role (default: SYSADMIN)
# - SNOWFLAKE_WAREHOUSE: Warehouse name (default: COMPUTE_WH)

# Check the file:
cat .env | grep -E "SNOWFLAKE_"
```

### 1.3 Verify environment variables are set

```bash
# Source the .env file
export $(cat .env | xargs)

# Verify key vars
echo "Account: $SNOWFLAKE_ACCOUNT"
echo "User: $SNOWFLAKE_USER"
echo "Database: $SNOWFLAKE_DATABASE"
```

---

## Step 2: Python Environment

### 2.1 Install uv (if needed)

```bash
command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 2.2 Sync Python dependencies

```bash
# This creates a .venv virtual environment and installs all deps
uv sync

# Verify Python is available with installed packages
./.venv/bin/python --version
./.venv/bin/python -c "import dlt; import dbt; print('✓ Core packages installed')"
```

### 2.3 Verify key packages

```bash
# Check individual packages
uv pip list | grep -E "dlt|dbt|titan|requests|python-dotenv"

# Expected output should include:
# - dlt (and snowflake extra)
# - dbt-core
# - dbt-snowflake
# - titan-core 0.11.1
# - requests
# - python-dotenv
```

---

## Step 3: Snowflake Infrastructure Setup

### 3.1 Verify Snowflake connectivity

```bash
# Test Snowflake connection
python -c "
import os
import snowflake.connector

os.environ.update({
    'SNOWFLAKE_ACCOUNT': os.getenv('SNOWFLAKE_ACCOUNT'),
    'SNOWFLAKE_USER': os.getenv('SNOWFLAKE_USER'),
    'SNOWFLAKE_PASSWORD': os.getenv('SNOWFLAKE_PASSWORD'),
    'SNOWFLAKE_ROLE': os.getenv('SNOWFLAKE_ROLE', 'SYSADMIN'),
})

try:
    session = snowflake.connector.connect(
        account=os.getenv('SNOWFLAKE_ACCOUNT'),
        user=os.getenv('SNOWFLAKE_USER'),
        password=os.getenv('SNOWFLAKE_PASSWORD'),
        role=os.getenv('SNOWFLAKE_ROLE'),
    )
    print('✓ Snowflake connection successful')
    session.close()
except Exception as e:
    print(f'✗ Connection failed: {e}')
"
```

### 3.2 Preview Titan infrastructure changes

```bash
# See what Titan will create (dry-run)
just titan-plan

# Expected output:
# » titan core
# » Plan: X to add, 0 to change, 0 to destroy.
# (showing database, schemas, warehouse, tables)
```

### 3.3 Apply Titan infrastructure

```bash
# Create the infrastructure in Snowflake
just titan-apply

# Expected: All resources created successfully
# - Database: SCHEMA_EVOLUTION_DB
# - Schemas: RAW, STAGING, INTERMEDIATE, MARTS, SNAPSHOTS
# - Warehouse: COMPUTE_WH (XSMALL)
# - Tables: WEATHER_FORECASTS_ICEBERG, WEATHER_HOURLY_ICEBERG
```

### 3.4 Verify infrastructure in Snowflake

```bash
# Query to verify resources were created
snowsql --config /dev/.snowsqlconfig << EOF
USE ROLE SYSADMIN;
USE DATABASE SCHEMA_EVOLUTION_DB;

-- List schemas
SHOW SCHEMAS;

-- List Iceberg tables in RAW
SHOW TABLES IN RAW;

-- List warehouse
SHOW WAREHOUSES;
EOF
```

---

## Step 4: dbt Setup & Validation

### 4.1 Install dbt packages

```bash
just dbt-deps

# Expected output shows installed packages:
# - dbt_utils
# - dbt_expectations
```

### 4.2 dbt compile (validates SQL without running)

```bash
cd transform
./.venv/bin/dbt compile --profiles-dir .
# Expected: Compile successful, all models parse correctly

# Check compilation output
ls target/compiled/schema_evolution
```

### 4.3 dbt documentation

```bash
cd transform
./.venv/bin/dbt docs generate --profiles-dir .

# Generates docs in target/
ls target/index.html
echo "✓ Documentation generated"
```

---

## Step 5: Docker Build & Validation

### 5.1 Build Docker image

```bash
# This creates a multi-stage Docker image with all dependencies
just build

# Or manually:
docker build -t schema-evolution:latest .

# Expected: Build completes successfully
# Multi-stage: base → deps → app
```

### 5.2 Verify Docker image

```bash
# Check image was built
docker image ls | grep schema-evolution

# Test image (dry-run)
docker compose run --rm extract --help
# Should show help for open_meteo_pipeline
```

---

## Step 6: Extraction Layer

### 6.1 Local extraction (V1 schema)

```bash
# This extracts using V1 schema (temperature + humidity only)
just extract-local

# Expected output:
# - Fetches data from Open-Meteo API (5 cities)
# - Loads into Snowflake RAW schema
# - Creates tables: weather_forecasts, weather_hourly
# - Shows load summary

# Verify in Snowflake
snowsql << EOF
USE SCHEMA_EVOLUTION_DB.RAW;
SELECT COUNT(*) FROM WEATHER_FORECASTS;
SELECT COUNT(*) FROM WEATHER_HOURLY;
EOF
```

### 6.2 Docker extraction (V1 schema)

```bash
# Run extraction via Docker
just extract

# Expected: Same as local but containerized
```

### 6.3 Local extraction (V2 schema - evolved)

```bash
# This extracts using V2 schema (adds precipitation, wind, UV)
just extract-local version=2

# Expected output:
# - Same cities but with additional columns
# - Snowflake detects new columns and adds them (schema evolution!)

# Verify new columns in Snowflake
snowsql << EOF
USE SCHEMA_EVOLUTION_DB.RAW;
DESCRIBE TABLE WEATHER_FORECASTS;
EOF
```

---

## Step 7: Transformation Layer (dbt)

### 7.1 Local dbt models (V1 data)

```bash
# Assumes V1 data was extracted
cd transform

# Rebuild all models from scratch
./.venv/bin/dbt run --full-refresh --profiles-dir .

# Expected: 
# - Staging models: stg_weather_forecasts, stg_weather_hourly
# - Intermediate models: int_weather_daily_agg
# - Marts: fct_weather_summary
# All models run successfully

# Check results
./.venv/bin/dbt test --profiles-dir .
```

### 7.2 dbt seed data

```bash
# Load lookup tables (cities, timezones)
cd transform
./.venv/bin/dbt seed --profiles-dir .

# Expected: location_lookup loaded into STAGING.LOCATION_LOOKUP
```

### 7.3 Docker dbt build

```bash
# Run full dbt build (models + tests) via Docker
just dbt-build

# Expected: All models + tests pass
```

---

## Step 8: Full Pipeline End-to-End

### 8.1 V1 Complete Pipeline

```bash
# Orchestrates: extract V1 → seed → dbt build
just pipeline-v1

# Expected:
# 1. Extract: weather data with V1 schema
# 2. Seed: location lookup table
# 3. dbt: all models + tests pass
# 4. Output: X rows in fct_weather_summary
```

### 8.2 V2 Complete Pipeline (Schema Evolution Demo)

```bash
# Demonstrates schema evolution:
# extract V2 (new columns) → dbt build (handles evolved schema)
just pipeline-v2

# Expected:
# 1. Extract: same data but with precipitation_sum, wind_speed, uv_index
# 2. dbt: handles new columns gracefully (safe_cast macro)
# 3. Result: fct_weather_summary now has schema_version=2 for new rows

# Verify evolution happened
snowsql << EOF
USE SCHEMA_EVOLUTION_DB.MARTS;
SELECT schema_version, COUNT(*) FROM fct_weather_summary GROUP BY schema_version;
-- Should show V1 and V2 data in same table
EOF
```

### 8.3 Full Demo (V1 then V2)

```bash
# Runs complete story: V1 baseline → V2 evolution
just demo

# This orchestrates:
# 1. pipeline-v1 (baseline)
# 2. pipeline-v2 (evolution)
# Story complete!
```

---

## Step 9: Verify Data Quality

### 9.1 Check for silent NULLs

```bash
# Run the NULL drift detection test
cd transform
./.venv/bin/dbt test -s assert_no_null_temperatures --profiles-dir .

# Expected: ✓ Test passes (no unexpected NULLs in temp fields)
```

### 9.2 Schema version tracking

```sql
-- Query to see evolution in action
SELECT 
    schema_version,
    COUNT(*) as row_count,
    MIN(forecast_date) as first_date,
    MAX(forecast_date) as last_date
FROM SCHEMA_EVOLUTION_DB.MARTS.fct_weather_summary
GROUP BY schema_version
ORDER BY schema_version;

-- Expected:
-- schema_version | row_count | first_date | last_date
-- 1              | X         | 2026-02-07 | 2026-02-16
-- 2              | Y         | 2026-02-07 | 2026-02-16
```

### 9.3 Backfill incremental model

```bash
# Test the incremental backfill pattern
cd transform
./.venv/bin/dbt run -s fct_weather_summary \
  --vars '{"start_date": "2026-02-07", "end_date": "2026-02-10"}' \
  --profiles-dir .

# Expected: Backfill completes, V1 rows now have V2 data via delete+insert
```

---

## Step 10: CI/CD Validation

### 10.1 Lint Python code

```bash
just lint

# Expected:
# - No ruff errors
# - extract/ code meets standards
```

### 10.2 dbt compile (CI mode)

```bash
cd transform
DBT_PROFILES_DIR=./transform \
  ./.venv/bin/dbt compile --profiles-dir . --target ci

# Expected: Compilation succeeds for CI target
```

### 10.3 Docker build (CI check)

```bash
# Same as Step 5 but validates Docker can build in CI
docker build -t schema-evolution:ci .
```

---

## Troubleshooting

### Issue: `uv sync` fails with module not found

**Solution:** 
```bash
# Ensure you have Python 3.10+ installed
python --version

# If using wrong Python, specify it:
uv sync --python 3.11
```

### Issue: Snowflake connection fails

**Solution:**
```bash
# Verify credentials are correct
cat .env | grep SNOWFLAKE_

# Test connection manually
snowsql
# In snowsql prompt: SELECT CURRENT_ACCOUNT();
```

### Issue: dbt compile fails

**Solution:**
```bash
cd transform

# Reinstall dbt packages
./.venv/bin/dbt deps --profiles-dir . --clean

# Recompile
./.venv/bin/dbt compile --profiles-dir .
```

### Issue: Docker build fails with "permission denied"

**Solution:**
```bash
# Ensure Docker daemon is running
docker ps

# Rebuild without cache
docker build --no-cache -t schema-evolution:latest .
```

### Issue: Titan plan shows errors

**Solution:**
```bash
# Verify titan config
cat titan.yml

# Check manifest syntax
./.venv/bin/python -c "from snowflake.manifest import bp; print('✓ Manifest valid')"
```

---

## Success Criteria

✅ All of the following should complete without errors:

1. `just setup-env` → .env created
2. `uv sync` → Virtual environment set up
3. `just titan-plan` → Infrastructure changes displayed
4. `just titan-apply` → Snowflake resources created
5. `just dbt-deps` → dbt packages installed
6. `just extract-local` → V1 data extracted and loaded
7. `just extract-local version=2` → V2 data with evolved schema
8. `just dbt-build-local` → All models and tests pass
9. `just pipeline-v1` → Full V1 pipeline succeeds
10. `just pipeline-v2` → Full V2 pipeline demonstrates evolution
11. `just demo` → Complete story (V1→V2) runs end-to-end

If all 11 steps pass, **the project is working correctly!** 🎉

---

## Next Steps

Once validation is complete:

1. **Phase 1**: Iceberg Time Travel exploration
2. **Phase 2**: Multi-format comparison (Delta, Hudi)
3. **Phase 3**: Advanced evolution scenarios
4. **Phase 4**: Evolution analytics & monitoring

See the [enhancement recommendations](docs/README.md) for details.
