#!/usr/bin/env python
"""
Titan IaC Apply Script

This script applies the infrastructure plan to Snowflake, creating all resources
defined in the blueprint manifest.
"""

import os
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
load_dotenv()

import snowflake.connector
from iac.manifest import bp as blueprint

def main():
    """Apply infrastructure changes to Snowflake"""
    
    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")
    password = os.getenv("SNOWFLAKE_PASSWORD")
    role = os.getenv("SNOWFLAKE_ROLE")
    warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
    
    if not all([account, user, password, role]):
        print("❌ Missing Snowflake credentials. Check .env file.")
        return 1
    
    print("🚀 Applying infrastructure changes...")
    print()
    
    try:
        session = snowflake.connector.connect(
            account=account,
            user=user,
            password=password,
            role=role,
            warehouse=warehouse,
        )
        
        cursor = session.cursor()
        
        # Create database
        print("📦 Creating database SCHEMA_EVOLUTION_DB...")
        cursor.execute("CREATE DATABASE IF NOT EXISTS SCHEMA_EVOLUTION_DB")
        print("   ✓ Database created")
        
        # Create schemas
        schemas = ["RAW", "STAGING", "INTERMEDIATE", "MARTS", "SNAPSHOTS"]
        for schema in schemas:
            print(f"📁 Creating schema {schema}...")
            cursor.execute(f"CREATE SCHEMA IF NOT EXISTS SCHEMA_EVOLUTION_DB.{schema}")
            print(f"   ✓ Schema {schema} created")
        
        # Create warehouse
        print("⚙️  Creating warehouse COMPUTE_WH...")
        cursor.execute("""
            CREATE WAREHOUSE IF NOT EXISTS COMPUTE_WH
            WAREHOUSE_SIZE='XSMALL'
            AUTO_SUSPEND=60
            AUTO_RESUME=TRUE
        """)
        print("   ✓ Warehouse created")
        
        # Create Iceberg tables
        print("🗂️  Creating Iceberg table WEATHER_FORECASTS_ICEBERG...")
        cursor.execute("""
            CREATE ICEBERG TABLE IF NOT EXISTS SCHEMA_EVOLUTION_DB.RAW.WEATHER_FORECASTS_ICEBERG (
                city VARCHAR,
                latitude FLOAT,
                longitude FLOAT,
                forecast_date DATE,
                temperature_2m_max FLOAT,
                temperature_2m_min FLOAT,
                apparent_temperature_max FLOAT,
                apparent_temperature_min FLOAT,
                sunrise VARCHAR,
                sunset VARCHAR,
                ingested_at TIMESTAMP_NTZ
            )
            CLUSTER BY (city, forecast_date)
            COMMENT='Daily weather forecasts - Iceberg table with explicit schema'
        """)
        print("   ✓ Table WEATHER_FORECASTS_ICEBERG created")
        
        print("🗂️  Creating Iceberg table WEATHER_HOURLY_ICEBERG...")
        cursor.execute("""
            CREATE ICEBERG TABLE IF NOT EXISTS SCHEMA_EVOLUTION_DB.RAW.WEATHER_HOURLY_ICEBERG (
                city VARCHAR,
                latitude FLOAT,
                longitude FLOAT,
                timestamp TIMESTAMP_NTZ,
                temperature_2m FLOAT,
                relative_humidity_2m FLOAT,
                apparent_temperature FLOAT,
                ingested_at TIMESTAMP_NTZ
            )
            CLUSTER BY (city, timestamp)
            COMMENT='Hourly weather observations - Iceberg table with explicit schema'
        """)
        print("   ✓ Table WEATHER_HOURLY_ICEBERG created")
        
        cursor.close()
        session.close()
        
        print()
        print("✅ Infrastructure applied successfully!")
        print()
        print("Next steps:")
        print("   • Run: just extract-local   (to load V1 weather data)")
        print("   • Run: just dbt-build-local (to transform data)")
        print("   • Run: just pipeline-v1    (full V1 pipeline)")
        
        return 0
        
    except Exception as e:
        print(f"❌ Error applying infrastructure: {e}")
        print()
        print("Troubleshooting:")
        print("   • Check Snowflake credentials and permissions")
        print("   • Ensure role has CREATE DATABASE privilege")
        print("   • Verify account and warehouse settings")
        return 1

if __name__ == "__main__":
    sys.exit(main())
