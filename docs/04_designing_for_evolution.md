# Part 4: Designing for Evolution

## Apache Iceberg schemas

Apache Iceberg brings **explicit, versioned schemas** to analytics storage:

### Key capabilities

1. **Schema versioning** — Every schema change creates a new version in Iceberg metadata
2. **Safe column additions** — `ADD COLUMN` is a metadata-only operation; existing data gets NULLs
3. **Column renames** — Tracked by column IDs, not names
4. **Type promotions** — `int → long`, `float → double` are safe
5. **Blocked breaking changes** — Dropping columns or incompatible type changes are prevented

### Snowflake-managed Iceberg tables

```sql
CREATE ICEBERG TABLE weather_forecasts_iceberg (
    city                     STRING,
    latitude                 FLOAT,
    longitude                FLOAT,
    forecast_date            DATE,
    temperature_2m_max       FLOAT,
    temperature_2m_min       FLOAT
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'my_iceberg_external_volume'
    BASE_LOCATION = 'weather_forecasts/';
```

### Schema evolution in action

When V2 fields arrive:

```sql
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
- Works with Snowflake's Iceberg table support

## Infrastructure as Code with Titan

Manually running SQL scripts to create tables is error-prone. This project uses **Titan**, a Python-based Infrastructure as Code tool for Snowflake, to define and manage all resources declaratively.

### Why Titan?

| Aspect | Manual SQL | Titan (IaC) |
|--------|-----------|-----------|
| Version control | Changes are ad-hoc | All changes tracked in git |
| Reproducibility | Manual + error-prone | Deterministic from code |
| Rollback | Manual ALTER/DROP | git revert + `titan apply` |
| Documentation | Separate README notes | Inline code + docstrings |
| Drift detection | None | `titan plan` shows differences |
| Schema evolution | Manual ALTER TABLE | Programmatic in manifest |

### Titan manifest

All Snowflake resources are defined in [snowflake/manifest.py](../snowflake/manifest.py):

```python
from titan import resources as res

database = res.Database(
    name="SCHEMA_EVOLUTION_DB",
    comment="Design for Schema Evolution demo project",
)

weather_forecasts_iceberg = res.IcebergTable(
    name="WEATHER_FORECASTS_ICEBERG",
    schema=raw_schema,
    columns=[
        res.Column(name="city", data_type="STRING"),
        res.Column(name="latitude", data_type="FLOAT"),
        res.Column(name="forecast_date", data_type="DATE"),
        # ... more columns
    ],
    catalog="SNOWFLAKE",
)
```

### Applying infrastructure

```bash
# See what will change (dry-run)
just titan-plan

# Apply the changes to Snowflake
just titan-apply

# Inspect a specific resource
just titan-describe SCHEMA_EVOLUTION_DB
```

### Schema evolution with Titan

After V2 data is available, evolve the Iceberg tables by adding columns to the manifest:

```python
weather_forecasts_iceberg = res.IcebergTable(
    # ... existing columns ...
    columns=[
        # ... V1 columns ...
        res.Column(name="precipitation_sum", data_type="FLOAT"),
        res.Column(name="wind_speed_10m_max", data_type="FLOAT"),
        res.Column(name="uv_index_max", data_type="FLOAT"),
    ],
)
```

Then:

```bash
just titan-plan    # Review the ADD COLUMN operations
just titan-apply   # Apply to Snowflake
```

Titan handles the safe Iceberg evolution—no manual ALTER TABLE needed.

## What to look at

- [snowflake/manifest.py](../snowflake/manifest.py) — Titan Infrastructure as Code for all Snowflake objects
- [extract/sources/open_meteo.py](../extract/sources/open_meteo.py) — V1 → V2 schema version switching

## Backfilling after schema evolution

When Iceberg (or Snowflake) schema evolution adds new columns, historical rows will contain
`NULL` for those columns. The `fct_weather_summary` mart uses an incremental `delete+insert`
strategy with idempotent backfill support to fix this.

### Step-by-step backfill workflow

1. **Detect the evolution** — dlt or Iceberg detects new V2 columns (precipitation, wind, UV).

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
