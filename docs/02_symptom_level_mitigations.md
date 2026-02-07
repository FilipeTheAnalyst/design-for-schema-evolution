# Part 2: Symptom-Level Mitigations

## What teams do today

When silent schema failures happen, teams typically apply these mitigations:

### 1. Defensive SQL

Use `TRY_CAST`, `COALESCE`, and `CASE` statements to handle missing or changed columns:

```sql
-- Instead of raw:qty::INT (which silently returns NULL)
COALESCE(TRY_CAST(raw:qty AS INT), TRY_CAST(raw:"Qty" AS INT), 0) AS quantity
```

In this project, we use a `safe_cast` macro:

```sql
{{ safe_cast('precipitation_sum', 'FLOAT') }} AS precipitation_sum_mm
```

This handles the case where V2 columns don't exist yet.

### 2. NULL-drift detection

Add dbt tests that catch unexpected NULLs in critical columns:

```sql
-- tests/assert_no_null_temperatures.sql
SELECT city, forecast_date
FROM {{ ref('fct_weather_summary') }}
WHERE forecast_temp_max_c IS NULL
```

### 3. Idempotent incremental backfills

Use dbt's `incremental` materialization with a surrogate key and `delete+insert` strategy.
The `fct_weather_summary` model supports two incremental modes:

**Default mode** — only new records are loaded:

```sql
{{ config(
    materialized='incremental',
    unique_key='weather_summary_key',
    incremental_strategy='delete+insert',
) }}

SELECT * FROM joined
WHERE 1=1
{% if is_incremental() %}
    AND ingested_at > (SELECT MAX(ingested_at) FROM {{ this }})
{% endif %}
```

**Backfill mode** — reprocess a specific date range (idempotent via `delete+insert`):

```sql
{% if var("start_date", none) and var("end_date", none) %}
    AND forecast_date >= '{{ var("start_date") }}'
    AND forecast_date <= '{{ var("end_date") }}'
{% endif %}
```

#### Running backfills after schema evolution

When V2 schema data arrives, earlier rows loaded under V1 will have `NULL` values for evolved
columns (`precipitation_sum_mm`, `wind_speed_max_kmh`, `uv_index_max`). To fix this:

```bash
# 1. Re-extract the affected date range with V2 schema
just extract-v2

# 2. Backfill the mart for the affected date range
cd transform
dbt run -s fct_weather_summary \
  --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}' \
  --profiles-dir .

# 3. Or with Docker
docker compose run --rm dbt-run \
  dbt run -s fct_weather_summary \
  --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}'

# 4. For a complete rebuild (drops and recreates the table)
dbt run -s fct_weather_summary --full-refresh --profiles-dir .
```

The `delete+insert` strategy ensures backfills are **idempotent** — running the same
backfill command multiple times produces the same result. Rows matching the surrogate
key (`weather_summary_key`, derived from `city` + `forecast_date`) are deleted before
the new data is inserted.

## The limitation

These are **symptom-level** fixes. They don't prevent the problem — they detect and recover from it. The root cause (implicit schemas) remains unaddressed.

## What to look at

- [transform/macros/safe_cast.sql](../transform/macros/safe_cast.sql) — defensive casting macro
- [transform/tests/](../transform/tests/) — NULL-drift detection tests
- [transform/snapshots/weather_snapshot.sql](../transform/snapshots/weather_snapshot.sql) — track changes over time
