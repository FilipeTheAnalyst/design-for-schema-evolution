# Part 4: Designing for Evolution

## Apache Iceberg schemas

Apache Iceberg brings **explicit, versioned schemas** to analytics storage:

### Key capabilities

1. **Schema versioning** — Every schema change creates a new version in Iceberg metadata
2. **Safe column additions** — `ADD COLUMN` is a metadata-only operation; existing data gets NULLs
3. **Column renames** — Tracked by column IDs, not names
4. **Type promotions** — `int → long`, `float → double` are safe
5. **Blocked breaking changes** — Dropping columns or incompatible type changes are prevented

### DuckDB-managed Iceberg tables

```sql
CREATE ICEBERG TABLE weather_forecasts (
    city                     VARCHAR,
    latitude                 DOUBLE,
    longitude                DOUBLE,
    forecast_date            DATE,
    temperature_2m_max       DOUBLE,
    temperature_2m_min       DOUBLE
)
USING ICEBERG;
```

### Schema evolution in action

When V2 fields arrive, dlt automatically adds them:

```sql
-- dlt detects new columns and adds them
ALTER TABLE weather_forecasts ADD COLUMN precipitation_sum DOUBLE;
ALTER TABLE weather_forecasts ADD COLUMN wind_speed_10m_max DOUBLE;
ALTER TABLE weather_forecasts ADD COLUMN uv_index_max DOUBLE;
```
-- Metadata-only operation — no data rewrite
ALTER ICEBERG TABLE weather_forecasts_iceberg ADD COLUMN precipitation_sum FLOAT;
ALTER ICEBERG TABLE weather_forecasts_iceberg ADD COLUMN wind_speed_10m_max FLOAT;
ALTER ICEBERG TABLE weather_forecasts_iceberg ADD COLUMN uv_index_max FLOAT;
```

Existing rows get `NULL` for the new columns. New rows include the data. The schema version is incremented in Iceberg's manifest.

### What changes

| Before (VARIANT) | After (Iceberg) |
|-------------------|-----------------|
| Schema inferred at query time | Schema declared at table creation |
| Column rename = silent NULL | Column rename = tracked by ID |
| No schema history | Full version history in metadata |
| Breaking changes are invisible | Breaking changes are blocked |

## dlt + Iceberg

dlt handles schema evolution natively:
- Detects new columns in API responses
- Adds them to the destination schema automatically
- Works with DuckDB's Iceberg table support

## Schema Management with DuckDB

In this project, schemas are managed through:
1. **dlt**: Automatically detects and adds new columns from the API
2. **Iceberg**: Enforces explicit, versioned schemas at the storage layer
3. **dbt**: Handles missing columns gracefully with the `safe_cast` macro

### Schema evolution workflow

The beauty of this approach is that **schema changes flow automatically**:

1. V1 extraction loads initial columns (temperature, humidity)
2. V2 extraction adds new columns (precipitation, wind, UV)
3. dlt automatically detects and adds columns to DuckDB
4. Iceberg validates the schema compatibility
5. dbt models adapt using `safe_cast` for optional columns

```bash
# Extract V1 (initial schema)
just extract
# → Tables created with V1 columns

# Extract V2 (evolved schema)
just extract-v2
# → dlt detects new columns and adds them

# Rebuild dbt models
just dbt-build
# → Models handle both V1 and V2 data gracefully
```

### Safe column casting in dbt

The `safe_cast` macro handles missing columns:

```sql
{{ dbt_utils.safe_cast("precipitation_sum", api.type_float(), "0.0") }}
```

This means:
- If `precipitation_sum` exists in V2 data → use its value
- If column is missing in V1 data → use default (0.0)
- Queries never fail due to missing columns

## What to look at

- [extract/open_meteo_pipeline.py](../extract/open_meteo_pipeline.py) — V1 → V2 schema version switching
- [transform/macros/safe_cast.sql](../transform/macros/safe_cast.sql) — Defensive column casting

## Backfilling after schema evolution

When Iceberg schema evolution adds new columns, historical rows will contain
`NULL` for those columns. The `fct_weather_summary` mart uses an incremental `delete+insert`
strategy with idempotent backfill support to fix this.

### Step-by-step backfill workflow

1. **Detect the evolution** — dlt detects new V2 columns (precipitation, wind, UV) and adds them to Iceberg.

2. **Re-extract historical data** with the V2 schema:
   ```bash
   just extract-v2
   ```

3. **Backfill the affected date range** in the mart:
   ```bash
   # Local
   cd transform && dbt run -s fct_weather_summary \
     --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}' \
     --profiles-dir .

   # Docker
   docker compose run --rm dbt-run \
     dbt run -s fct_weather_summary \
     --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}'
   ```

4. **Verify** the backfill filled the previously-NULL evolved columns:
   ```sql
   SELECT schema_version, COUNT(*)
   FROM marts.fct_weather_summary
   WHERE forecast_date BETWEEN '2026-01-01' AND '2026-01-31'
   GROUP BY 1;
   -- Expected: all rows should now show schema_version = 2
   ```

5. **(Optional) Full refresh** if you want a complete rebuild:
   ```bash
   dbt run -s fct_weather_summary --full-refresh --profiles-dir .
   ```

The backfill is **idempotent** — the `delete+insert` strategy on `weather_summary_key`
(surrogate key from `city` + `forecast_date`) ensures that re-running the same command
won't create duplicates.
