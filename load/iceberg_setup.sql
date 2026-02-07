-- =============================================================================
-- Apache Iceberg Table Setup for Snowflake
-- =============================================================================
-- This script creates Iceberg-managed tables that provide:
--   • Explicit, versioned schemas (no more implicit VARIANT parsing)
--   • Safe column additions without breaking downstream consumers
--   • Schema evolution metadata tracked in Iceberg's manifest files
--   • Time-travel and snapshot isolation
--
-- NOTE: Snowflake-managed Iceberg tables require an EXTERNAL VOLUME.
-- For a free trial / demo, you can use Snowflake-managed storage.
-- Adjust the EXTERNAL_VOLUME and CATALOG references for your setup.
--
-- Docs: https://docs.snowflake.com/en/user-guide/tables-iceberg
-- =============================================================================

USE ROLE SYSADMIN;
USE DATABASE SCHEMA_EVOLUTION_DB;
USE SCHEMA RAW;
USE WAREHOUSE COMPUTE_WH;

-- ─── Option A: Snowflake-managed Iceberg tables (simplest for demos) ─────────
-- These use Snowflake as both catalog and storage.

-- Daily forecast summaries
CREATE OR REPLACE ICEBERG TABLE weather_forecasts_iceberg (
    city                        STRING,
    latitude                    FLOAT,
    longitude                   FLOAT,
    forecast_date               DATE,
    temperature_2m_max          FLOAT,
    temperature_2m_min          FLOAT,
    apparent_temperature_max    FLOAT,
    apparent_temperature_min    FLOAT,
    sunrise                     STRING,
    sunset                      STRING,
    ingested_at                 TIMESTAMP_NTZ
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'my_iceberg_external_volume'   -- replace with your volume
    BASE_LOCATION = 'schema_evolution/weather_forecasts/'
    COMMENT = 'Daily weather forecasts – Iceberg table with explicit schema';


-- Hourly weather detail
CREATE OR REPLACE ICEBERG TABLE weather_hourly_iceberg (
    city                     STRING,
    latitude                 FLOAT,
    longitude                FLOAT,
    timestamp                TIMESTAMP_NTZ,
    temperature_2m           FLOAT,
    relative_humidity_2m     FLOAT,
    apparent_temperature     FLOAT,
    ingested_at              TIMESTAMP_NTZ
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = 'my_iceberg_external_volume'   -- replace with your volume
    BASE_LOCATION = 'schema_evolution/weather_hourly/'
    COMMENT = 'Hourly weather observations – Iceberg table with explicit schema';


-- =============================================================================
-- Schema Evolution Examples (run these AFTER the V1 data is loaded)
-- =============================================================================

-- ── V2: Add columns for precipitation, wind, UV ──────────────────────────────
-- Iceberg supports safe ADD COLUMN — existing data gets NULLs for new columns,
-- and the schema version is incremented in Iceberg metadata.

-- ALTER ICEBERG TABLE weather_forecasts_iceberg ADD COLUMN precipitation_sum FLOAT;
-- ALTER ICEBERG TABLE weather_forecasts_iceberg ADD COLUMN wind_speed_10m_max FLOAT;
-- ALTER ICEBERG TABLE weather_forecasts_iceberg ADD COLUMN uv_index_max FLOAT;

-- ALTER ICEBERG TABLE weather_hourly_iceberg ADD COLUMN precipitation FLOAT;
-- ALTER ICEBERG TABLE weather_hourly_iceberg ADD COLUMN wind_speed_10m FLOAT;
-- ALTER ICEBERG TABLE weather_hourly_iceberg ADD COLUMN wind_direction_10m FLOAT;

-- ── Verify schema versioning ─────────────────────────────────────────────────
-- SELECT * FROM TABLE(INFORMATION_SCHEMA.TABLE_STORAGE_METRICS('WEATHER_FORECASTS_ICEBERG'));

SELECT 'Iceberg table setup complete ✓' AS status;
