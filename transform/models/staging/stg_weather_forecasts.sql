-- stg_weather_forecasts.sql
-- Staging model: light cleaning of raw daily forecast data from dlt.
-- Handles schema evolution gracefully — new columns appear as NULLs
-- until the upstream source starts providing them.

with source as (

    select * from {{ source('raw', 'weather_forecasts') }}

),

renamed as (

    select
        -- ─── Dimensions ──────────────────────────────────────────────
        city,
        latitude,
        longitude,
        cast(forecast_date as date)                     as forecast_date,

        -- ─── V1: Core temperature metrics ────────────────────────────
        cast(temperature_2m_max as float)               as temperature_max_c,
        cast(temperature_2m_min as float)               as temperature_min_c,
        cast(apparent_temperature_max as float)          as feels_like_max_c,
        cast(apparent_temperature_min as float)          as feels_like_min_c,
        sunrise,
        sunset,

        -- ─── V2: Evolved fields (NULL until schema version 2) ───────
        -- These columns demonstrate safe schema evolution.
        -- dlt adds the columns automatically; dbt handles NULLs.
        {{ safe_cast('precipitation_sum', 'FLOAT') }}   as precipitation_sum_mm,
        {{ safe_cast('wind_speed_10m_max', 'FLOAT') }}  as wind_speed_max_kmh,
        {{ safe_cast('uv_index_max', 'FLOAT') }}        as uv_index_max,

        -- ─── Metadata ────────────────────────────────────────────────
        cast(ingested_at as timestamp_ntz)              as ingested_at,
        _dlt_load_id                                    as load_id

    from source

)

select * from renamed
