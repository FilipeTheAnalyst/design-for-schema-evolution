-- int_weather_daily_agg.sql
-- Aggregates hourly observations into daily city-level summaries.
-- Serves as a reconciliation layer between raw hourly and daily forecast data.

with hourly as (

    select * from {{ ref('stg_weather_hourly') }}

),

daily_agg as (

    select
        city,
        latitude,
        longitude,
        observation_date,

        -- ─── Temperature ─────────────────────────────────────────────
        round(avg(temperature_c), 1)                           as avg_temperature_c,
        round(max(temperature_c), 1)                           as max_temperature_c,
        round(min(temperature_c), 1)                           as min_temperature_c,

        -- ─── Humidity ────────────────────────────────────────────────
        round(avg(relative_humidity_pct), 1)                   as avg_humidity_pct,

        -- ─── Feels-like ──────────────────────────────────────────────
        round(avg(feels_like_c), 1)                            as avg_feels_like_c,

        -- ─── V2: Evolved fields (NULLs until V2 data arrives) ───────
        round(sum(precipitation_mm), 1)                        as total_precipitation_mm,
        round(max(wind_speed_kmh), 1)                          as max_wind_speed_kmh,

        -- ─── Metadata ────────────────────────────────────────────────
        count(*)                                               as observation_count,
        max(ingested_at)                                       as last_ingested_at

    from hourly
    group by 1, 2, 3, 4

)

select * from daily_agg
