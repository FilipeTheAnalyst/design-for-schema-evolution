# Part 1: Silent Schema Failures

## The problem

Consider a simple JSON payload from a weather API:

```json
{
  "city": "New York",
  "temperature_2m_max": 28.5,
  "temperature_2m_min": 18.2,
  "qty": 7
}
```

One day, the upstream API renames `qty` → `Qty`, or adds a new field like `precipitation_sum`. What happens?

### In Snowflake with VARIANT

If you're loading this JSON into a `VARIANT` column and parsing with:

```sql
SELECT
    raw:city::STRING AS city,
    raw:temperature_2m_max::FLOAT AS temp_max,
    raw:qty::INT AS quantity  -- silently becomes NULL when key changes to "Qty"
FROM raw_weather
```

**No error is raised.** The pipeline keeps running. The column silently returns `NULL`.

### In this project

We demonstrate this with the Open-Meteo API:

1. **V1 extraction** loads temperature + humidity fields
2. **V2 extraction** adds precipitation, wind speed, and UV index
3. dbt models reference the new columns — they appear as `NULL` until V2 data arrives

This mirrors real production incidents where:
- Pipelines stay green
- Dashboards show `0` or blank instead of real values
- Teams discover the issue weeks later

## Key takeaway

> The absence of an error is not evidence of correctness.

**Silent NULLs** are the most common symptom of implicit schema contracts breaking.

## What to look at

- [extract/sources/open_meteo.py](../extract/sources/open_meteo.py) — V1 vs V2 param lists
- [transform/models/staging/stg_weather_forecasts.sql](../transform/models/staging/stg_weather_forecasts.sql) — `safe_cast` on evolved columns
- [transform/tests/assert_no_null_temperatures.sql](../transform/tests/assert_no_null_temperatures.sql) — catches silent NULL drift
