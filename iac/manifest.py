"""
Snowflake Infrastructure as Code using Titan

This manifest defines all Snowflake resources for the schema evolution project:
  • Database: SCHEMA_EVOLUTION_DB
  • Schemas: RAW, STAGING, INTERMEDIATE, MARTS, SNAPSHOTS
  • Warehouse: COMPUTE_WH
  • Iceberg tables: weather_forecasts_iceberg, weather_hourly_iceberg

Run with:
    just titan-plan               # Show planned changes without applying
    just titan-apply              # Apply changes to Snowflake

Docs: https://titan.readthedocs.io/
"""

import os
import snowflake.connector

from titan.blueprint import Blueprint, print_plan
from titan import resources as res


def get_snowflake_session():
    """Create a Snowflake session using environment variables."""
    connection_params = {
        "account": os.environ.get("SNOWFLAKE_ACCOUNT"),
        "user": os.environ.get("SNOWFLAKE_USER"),
        "password": os.environ.get("SNOWFLAKE_PASSWORD"),
        "role": os.environ.get("SNOWFLAKE_ROLE", "SYSADMIN"),
    }
    return snowflake.connector.connect(**connection_params)


# =============================================================================
# Database & Schemas
# =============================================================================

database = res.Database(
    name="SCHEMA_EVOLUTION_DB",
    comment="Design for Schema Evolution demo project",
)

raw_schema = res.Schema(
    name="RAW",
    database=database,
    comment="Raw data ingested by dlt from Open-Meteo API",
)

staging_schema = res.Schema(
    name="STAGING",
    database=database,
    comment="dbt staging layer – light cleaning and renaming",
)

intermediate_schema = res.Schema(
    name="INTERMEDIATE",
    database=database,
    comment="dbt intermediate layer – business logic aggregations",
)

marts_schema = res.Schema(
    name="MARTS",
    database=database,
    comment="dbt marts layer – final consumption-ready tables",
)

snapshots_schema = res.Schema(
    name="SNAPSHOTS",
    database=database,
    comment="dbt snapshots layer – change data capture and auditing",
)

# =============================================================================
# Warehouse
# =============================================================================

compute_warehouse = res.Warehouse(
    name="COMPUTE_WH",
    warehouse_size="XSMALL",
    auto_suspend=60,
    auto_resume=True,
    comment="Default compute for schema evolution project",
)

# =============================================================================
# Iceberg Tables (V1 Schema)
# =============================================================================

weather_forecasts_iceberg = res.SnowflakeIcebergTable(
    name="WEATHER_FORECASTS_ICEBERG",
    schema=raw_schema,
    columns=[
        res.Column(name="city", data_type="STRING"),
        res.Column(name="latitude", data_type="FLOAT"),
        res.Column(name="longitude", data_type="FLOAT"),
        res.Column(name="forecast_date", data_type="DATE"),
        res.Column(name="temperature_2m_max", data_type="FLOAT"),
        res.Column(name="temperature_2m_min", data_type="FLOAT"),
        res.Column(name="apparent_temperature_max", data_type="FLOAT"),
        res.Column(name="apparent_temperature_min", data_type="FLOAT"),
        res.Column(name="sunrise", data_type="STRING"),
        res.Column(name="sunset", data_type="STRING"),
        res.Column(name="ingested_at", data_type="TIMESTAMP_NTZ"),
    ],
    comment="Daily weather forecasts – Iceberg table with explicit schema",
    catalog="SNOWFLAKE",
)

weather_hourly_iceberg = res.SnowflakeIcebergTable(
    name="WEATHER_HOURLY_ICEBERG",
    schema=raw_schema,
    columns=[
        res.Column(name="city", data_type="STRING"),
        res.Column(name="latitude", data_type="FLOAT"),
        res.Column(name="longitude", data_type="FLOAT"),
        res.Column(name="timestamp", data_type="TIMESTAMP_NTZ"),
        res.Column(name="temperature_2m", data_type="FLOAT"),
        res.Column(name="relative_humidity_2m", data_type="FLOAT"),
        res.Column(name="apparent_temperature", data_type="FLOAT"),
        res.Column(name="ingested_at", data_type="TIMESTAMP_NTZ"),
    ],
    comment="Hourly weather observations – Iceberg table with explicit schema",
    catalog="SNOWFLAKE",
)

# =============================================================================
# Blueprint
# =============================================================================

bp = Blueprint(
    resources=[
        database,
        raw_schema,
        staging_schema,
        intermediate_schema,
        marts_schema,
        snapshots_schema,
        compute_warehouse,
        weather_forecasts_iceberg,
        weather_hourly_iceberg,
    ],
)

# =============================================================================
# V2 Schema Evolution (add columns after V1 data is loaded)
# =============================================================================
#
# After V1 data is loaded and schema evolution is detected, add these columns:
#
# weather_forecasts_iceberg.columns.extend([
#     res.Column(name="precipitation_sum", data_type="FLOAT"),
#     res.Column(name="wind_speed_10m_max", data_type="FLOAT"),
#     res.Column(name="uv_index_max", data_type="FLOAT"),
# ])
#
# weather_hourly_iceberg.columns.extend([
#     res.Column(name="precipitation", data_type="FLOAT"),
#     res.Column(name="wind_speed_10m", data_type="FLOAT"),
#     res.Column(name="wind_direction_10m", data_type="FLOAT"),
# ])
#
# Then run: just titan-plan && just titan-apply

