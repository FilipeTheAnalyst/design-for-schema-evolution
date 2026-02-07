-- tests/assert_no_null_temperatures.sql
-- Custom test: ensure that core temperature fields are never NULL
-- in the final mart table. This catches silent schema failures.

select
    city,
    forecast_date,
    forecast_temp_max_c,
    forecast_temp_min_c

from {{ ref('fct_weather_summary') }}

where
    forecast_temp_max_c is null
    or forecast_temp_min_c is null
