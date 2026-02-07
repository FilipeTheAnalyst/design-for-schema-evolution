-- snapshots/weather_snapshot.sql
-- Snapshot the daily forecast mart to track how forecasts change over time.
-- This is useful for detecting schema drift and auditing data.

{% snapshot weather_forecast_snapshot %}

{{
    config(
        target_schema='snapshots',
        unique_key='weather_summary_key',
        strategy='check',
        check_cols=[
            'forecast_temp_max_c',
            'forecast_temp_min_c',
            'forecast_precip_mm',
            'forecast_wind_max_kmh',
            'uv_index_max',
        ],
    )
}}

select * from {{ ref('fct_weather_summary') }}

{% endsnapshot %}
