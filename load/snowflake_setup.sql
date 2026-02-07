-- =============================================================================
-- Snowflake Setup Script
-- =============================================================================
-- Run this once to set up the database, schemas, warehouse, and roles
-- needed for the schema evolution project.
--
-- Prerequisites:
--   1. A Snowflake account (free trial: https://signup.snowflake.com/)
--   2. ACCOUNTADMIN or SYSADMIN role access
-- =============================================================================

USE ROLE SYSADMIN;

-- ─── Database ────────────────────────────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS SCHEMA_EVOLUTION_DB
    COMMENT = 'Design for Schema Evolution demo project';

USE DATABASE SCHEMA_EVOLUTION_DB;

-- ─── Schemas ─────────────────────────────────────────────────────────────────
-- RAW:          Where dlt lands extracted data
-- STAGING:      dbt staging models
-- INTERMEDIATE: dbt intermediate models
-- MARTS:        dbt mart / final models

CREATE SCHEMA IF NOT EXISTS RAW
    COMMENT = 'Raw data ingested by dlt from Open-Meteo API';

CREATE SCHEMA IF NOT EXISTS STAGING
    COMMENT = 'dbt staging layer – light cleaning and renaming';

CREATE SCHEMA IF NOT EXISTS INTERMEDIATE
    COMMENT = 'dbt intermediate layer – business logic aggregations';

CREATE SCHEMA IF NOT EXISTS MARTS
    COMMENT = 'dbt marts layer – final consumption-ready tables';

-- ─── Warehouse ───────────────────────────────────────────────────────────────
CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    COMMENT = 'Default compute for schema evolution project';

-- ─── Grant usage (if using a dedicated role) ─────────────────────────────────
-- Uncomment and adjust if you create a dedicated role:
--
-- USE ROLE SECURITYADMIN;
-- CREATE ROLE IF NOT EXISTS SCHEMA_EVOLUTION_ROLE;
-- GRANT USAGE ON DATABASE SCHEMA_EVOLUTION_DB TO ROLE SCHEMA_EVOLUTION_ROLE;
-- GRANT USAGE ON ALL SCHEMAS IN DATABASE SCHEMA_EVOLUTION_DB TO ROLE SCHEMA_EVOLUTION_ROLE;
-- GRANT ALL PRIVILEGES ON ALL SCHEMAS IN DATABASE SCHEMA_EVOLUTION_DB TO ROLE SCHEMA_EVOLUTION_ROLE;
-- GRANT USAGE ON WAREHOUSE COMPUTE_WH TO ROLE SCHEMA_EVOLUTION_ROLE;
-- GRANT ROLE SCHEMA_EVOLUTION_ROLE TO USER <your_username>;

SELECT 'Snowflake setup complete ✓' AS status;
