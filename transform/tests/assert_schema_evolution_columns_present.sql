-- tests/assert_schema_evolution_columns_present.sql
-- Validates that when schema_version = 2, the evolved columns actually have data.
-- If V2 data is loaded but precipitation is NULL, something went wrong upstream.

select
    city,
    forecast_date,
    schema_version,
    forecast_precip_mm,
    forecast_wind_max_kmh,
    uv_index_max

from {{ ref('fct_weather_summary') }}

where
    schema_version = 2
    and (
        forecast_precip_mm is null
        and forecast_wind_max_kmh is null
        and uv_index_max is null
    )
