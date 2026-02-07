-- fct_weather_summary.sql
-- Final mart table: joins daily forecast with hourly aggregations
-- and enriches with location metadata from the seed table.
-- Designed to be the single source of truth for weather analytics.
--
-- Incremental with idempotent backfill support:
--   Default:   loads only new records based on max(ingested_at) in this table
--   Backfill:  dbt run -s fct_weather_summary --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}'
--   Full:      dbt run -s fct_weather_summary --full-refresh

{{
    config(
        materialized='incremental',
        unique_key='weather_summary_key',
        incremental_strategy='delete+insert',
    )
}}

with forecasts as (

    select * from {{ ref('stg_weather_forecasts') }}

),

hourly_agg as (

    select * from {{ ref('int_weather_daily_agg') }}

),

locations as (

    select * from {{ ref('location_lookup') }}

),

joined as (

    select
        -- ─── Surrogate key ───────────────────────────────────────────
        {{ dbt_utils.generate_surrogate_key(['f.city', 'f.forecast_date']) }}
            as weather_summary_key,

        -- ─── Location ────────────────────────────────────────────────
        f.city,
        l.country,
        l.timezone,
        f.latitude,
        f.longitude,
        f.forecast_date,

        -- ─── Forecast (daily API) ───────────────────────────────────
        f.temperature_max_c                             as forecast_temp_max_c,
        f.temperature_min_c                             as forecast_temp_min_c,
        f.feels_like_max_c                              as forecast_feels_like_max_c,
        f.feels_like_min_c                              as forecast_feels_like_min_c,
        f.sunrise,
        f.sunset,

        -- ─── Observed (hourly aggregation) ──────────────────────────
        h.avg_temperature_c                             as observed_avg_temp_c,
        h.max_temperature_c                             as observed_max_temp_c,
        h.min_temperature_c                             as observed_min_temp_c,
        h.avg_humidity_pct                              as observed_avg_humidity_pct,
        h.avg_feels_like_c                              as observed_avg_feels_like_c,
        h.observation_count,

        -- ─── V2: Evolved fields ─────────────────────────────────────
        f.precipitation_sum_mm                          as forecast_precip_mm,
        h.total_precipitation_mm                        as observed_precip_mm,
        f.wind_speed_max_kmh                            as forecast_wind_max_kmh,
        h.max_wind_speed_kmh                            as observed_wind_max_kmh,
        f.uv_index_max,

        -- ─── Derived: forecast vs observed delta ────────────────────
        round(
            f.temperature_max_c - coalesce(h.max_temperature_c, f.temperature_max_c), 1
        )                                               as temp_max_delta_c,

        -- ─── Schema evolution tracking ──────────────────────────────
        case
            when f.precipitation_sum_mm is not null then 2
            else 1
        end                                             as schema_version,

        -- ─── Metadata ───────────────────────────────────────────────
        f.ingested_at,
        f.load_id

    from forecasts f
    left join hourly_agg h
        on f.city = h.city
        and f.forecast_date = h.observation_date
    left join locations l
        on f.city = l.city

)

select * from joined
where 1=1

{% if is_incremental() %}
    {% if var("start_date", none) and var("end_date", none) %}
        -- Backfill logic: used when start_date and end_date vars are passed
        -- Usage: dbt run -s fct_weather_summary --vars '{"start_date": "2026-01-01", "end_date": "2026-01-31"}'
        and forecast_date >= '{{ var("start_date") }}'
        and forecast_date <= '{{ var("end_date") }}'

    {% else %}
        -- Default incremental logic: loads only new records based on the existing table
        and ingested_at > (select max(ingested_at) from {{ this }})

    {% endif %}
{% endif %}
