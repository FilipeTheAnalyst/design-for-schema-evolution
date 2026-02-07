-- stg_weather_hourly.sql
-- Staging model: light cleaning of raw hourly weather data from dlt.

with source as (

    select * from {{ source('raw', 'weather_hourly') }}

),

renamed as (

    select
        -- ─── Dimensions ──────────────────────────────────────────────
        city,
        latitude,
        longitude,
        cast(timestamp as timestamp_ntz)                   as observation_ts,
        cast(timestamp as date)                            as observation_date,

        -- ─── V1: Core hourly metrics ────────────────────────────────
        cast(temperature_2m as float)                      as temperature_c,
        cast(relative_humidity_2m as float)                 as relative_humidity_pct,
        cast(apparent_temperature as float)                 as feels_like_c,

        -- ─── V2: Evolved fields (NULL until schema version 2) ───────
        {{ safe_cast('precipitation', 'FLOAT') }}          as precipitation_mm,
        {{ safe_cast('wind_speed_10m', 'FLOAT') }}         as wind_speed_kmh,
        {{ safe_cast('wind_direction_10m', 'FLOAT') }}     as wind_direction_deg,

        -- ─── Metadata ────────────────────────────────────────────────
        cast(ingested_at as timestamp_ntz)                 as ingested_at,
        _dlt_load_id                                       as load_id

    from source

)

select * from renamed
