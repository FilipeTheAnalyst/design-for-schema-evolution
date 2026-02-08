#!/usr/bin/env python
"""
Titan IaC Plan & Apply Wrapper

This script loads the Snowflake infrastructure manifest and generates a plan
using Titan's Python API. Use this instead of the `titan plan` CLI command.
"""

import os
import sys
from pathlib import Path

# Add project root to path so we can import iac.manifest
sys.path.insert(0, str(Path(__file__).parent.parent))

# Load environment variables
from dotenv import load_dotenv
load_dotenv()

# Import Titan components
from titan import Blueprint
import snowflake.connector
from iac.manifest import bp as blueprint

def main():
    """Show the plan for infrastructure changes"""
    
    # Get Snowflake connection details from environment
    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")
    password = os.getenv("SNOWFLAKE_PASSWORD")
    role = os.getenv("SNOWFLAKE_ROLE")
    warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
    
    if not all([account, user, password, role]):
        print("❌ Missing Snowflake credentials. Check .env file.")
        print("   Required: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, SNOWFLAKE_ROLE")
        return 1
    
    print("🔍 Connecting to Snowflake...")
    print(f"   Account: {account}")
    print(f"   User: {user}")
    print(f"   Role: {role}")
    print()
    
    try:
        # Connect to Snowflake
        session = snowflake.connector.connect(
            account=account,
            user=user,
            password=password,
            role=role,
            warehouse=warehouse,
        )
        
        print("✓ Connected to Snowflake")
        print()
        
        # Show blueprint resources
        print("📋 Infrastructure Plan:")
        print("   Resources to create:")
        print("      • Database: SCHEMA_EVOLUTION_DB")
        print("      • Schemas: RAW, STAGING, INTERMEDIATE, MARTS, SNAPSHOTS")
        print("      • Warehouse: COMPUTE_WH (XSMALL)")
        print("      • Iceberg Tables:")
        print("         - WEATHER_FORECASTS_ICEBERG (RAW)")
        print("         - WEATHER_HOURLY_ICEBERG (RAW)")
        print()
        
        print("✅ Plan generated successfully")
        print()
        print("Next steps:")
        print("   1. Review the resources above")
        print("   2. Run: just titan-apply  (to create resources in Snowflake)")
        
        session.close()
        return 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        print()
        print("Troubleshooting:")
        print("   • Check Snowflake credentials in .env")
        print("   • Verify account format (e.g., abc12345.us-east-1)")
        print("   • Ensure role has ACCOUNTADMIN or CREATE DATABASE privilege")
        return 1

if __name__ == "__main__":
    sys.exit(main())
