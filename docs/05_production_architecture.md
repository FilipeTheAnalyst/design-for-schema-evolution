# Part 5: Production Architecture

## How the layers work together

```
┌────────────────────────────────────────────────────────────────┐
│                     Open-Meteo API                             │
│                (free, no auth, JSON)                            │
└─────────────────────────┬──────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────────────┐
│                     dlt (dlthub)                               │
│          Extract + Load → Snowflake                            │
│     • Schema inference & evolution                             │
│     • V1 → V2 column additions tracked                         │
└─────────────────────────┬──────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────────────┐
│              Snowflake + Apache Iceberg                         │
│     • RAW schema: dlt-managed tables                           │
│     • Iceberg tables: explicit, versioned schemas              │
│     • STAGING / INTERMEDIATE / MARTS schemas                    │
└─────────────────────────┬──────────────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────────────┐
│                     dbt Core                                   │
│     • Staging: clean + rename + safe_cast                      │
│     • Intermediate: daily aggregation                          │
│     • Marts: joined fact table with schema_version tracking    │
│     • Tests: NULL-drift detection                              │
│     • Snapshots: change tracking over time                     │
└────────────────────────────────────────────────────────────────┘
```

## Responsibility per layer

| Layer | Tool | Responsibility |
|-------|------|----------------|
| **Extract** | dlt | API → Snowflake, schema inference, column evolution |
| **Store** | Snowflake + Iceberg | Explicit schemas, versioned metadata, safe evolution |
| **Transform** | dbt | Cleaning, aggregation, testing, documentation |
| **Orchestrate** | Docker + just + GitHub Actions | Reproducibility, CI/CD, scheduling |

## Key design decisions

1. **dlt handles schema evolution at ingestion** — new columns are detected and added automatically
2. **Iceberg enforces schemas at storage** — breaking changes are caught before they propagate
3. **dbt tests catch symptoms** — NULL-drift and data quality checks as a safety net
4. **Schema version is tracked in the mart** — analysts can see which data generation they're working with

## The layered defense

```
API schema change
    │
    ├─ dlt detects new columns → adds to Snowflake ✓
    │
    ├─ Iceberg validates schema compatibility ✓
    │
    ├─ dbt safe_cast handles missing columns ✓
    │
    └─ dbt tests catch NULL drift ✓
```

No single layer solves everything. The architecture works because **each layer handles what it's best at**.

## Incremental backfill after schema evolution

In production, schema evolution creates a gap: new columns exist in the schema but historical
rows have `NULL` values. The `fct_weather_summary` mart handles this with an idempotent
backfill pattern.

### When to backfill

- After running V2 extraction (`just extract-v2`) which adds new columns
- After Iceberg `ALTER TABLE ... ADD COLUMN` operations
- After fixing a dlt source that was missing fields
- Whenever `schema_version = 1` rows need to be refreshed with V2 data

### How to backfill

```bash
# Backfill a specific date range (idempotent — safe to re-run)
dbt run -s fct_weather_summary \
  --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}' \
  --profiles-dir .

# Backfill via Docker
docker compose run --rm dbt-run \
  dbt run -s fct_weather_summary \
  --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}'

# Full refresh (drops table and rebuilds from scratch)
dbt run -s fct_weather_summary --full-refresh --profiles-dir .
```

### How it works

1. The model uses `incremental_strategy='delete+insert'` with a surrogate key (`weather_summary_key`)
2. When `start_date` and `end_date` vars are passed, it filters to that date range
3. The `delete+insert` strategy deletes existing rows matching the surrogate key, then inserts fresh data
4. Without vars, it defaults to only loading rows newer than `max(ingested_at)` in the table

This means the same backfill command can be run multiple times without creating duplicates.

### GitHub Actions backfill

To trigger a backfill from CI/CD, use the deploy workflow with manual dispatch:

```yaml
# In .github/workflows/deploy.yml, add to the dbt step:
dbt run -s fct_weather_summary \
  --vars '{"start_date": "${{ github.event.inputs.start_date }}", "end_date": "${{ github.event.inputs.end_date }}"}'
```

## What to look at

- [justfile](../justfile) — `just demo` runs the full V1 → V2 pipeline
- [docker-compose.yml](../docker-compose.yml) — containerized pipeline services
- [.github/workflows/](../.github/workflows/) — CI/CD automation
