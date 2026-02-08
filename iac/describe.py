#!/usr/bin/env python
"""
Titan IaC Describe Script

Show details about Snowflake resources (databases, schemas, tables, etc.)
"""

import os
import sys
from pathlib import Path

# Add project root to path
sys.path.insert(0, str(Path(__file__).parent.parent))

from dotenv import load_dotenv
load_dotenv()

import snowflake.connector

def main(resource=None):
    """Describe Snowflake resources"""
    
    account = os.getenv("SNOWFLAKE_ACCOUNT")
    user = os.getenv("SNOWFLAKE_USER")
    password = os.getenv("SNOWFLAKE_PASSWORD")
    role = os.getenv("SNOWFLAKE_ROLE")
    warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", "COMPUTE_WH")
    
    if not all([account, user, password, role]):
        print("❌ Missing Snowflake credentials. Check .env file.")
        return 1
    
    print("🔍 Describing Snowflake resources...")
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
        
        # If specific resource provided
        if resource and resource != "SCHEMA_EVOLUTION_DB":
            cursor.execute(f"DESCRIBE {resource}")
            cols = cursor.fetchall()
            print(f"Resource: {resource}")
            for row in cols:
                print(f"  {row}")
            cursor.close()
            session.close()
            return 0
        
        # Show databases
        print("🗃️  Databases:")
        cursor.execute("SHOW DATABASES LIKE '%SCHEMA_EVOLUTION%'")
        dbs = cursor.fetchall()
        if dbs:
            for db in dbs:
                print(f"   • {db[1]}")
        else:
            print("   (none - create with 'just titan-apply')")
        print()
        
        # Show schemas in SCHEMA_EVOLUTION_DB
        print("📁 Schemas in SCHEMA_EVOLUTION_DB:")
        cursor.execute("SHOW SCHEMAS IN DATABASE SCHEMA_EVOLUTION_DB")
        schemas = cursor.fetchall()
        if schemas:
            for schema in schemas:
                print(f"   • {schema[1]}")
        else:
            print("   (none - create with 'just titan-apply')")
        print()
        
        # Show tables
        print("🗂️  Tables in SCHEMA_EVOLUTION_DB.RAW:")
        cursor.execute("SHOW TABLES IN SCHEMA_EVOLUTION_DB.RAW")
        tables = cursor.fetchall()
        if tables:
            for table in tables:
                print(f"   • {table[1]}")
        else:
            print("   (none - load with 'just extract-local')")
        print()
        
        # Show warehouses
        print("⚙️  Compute Warehouses:")
        cursor.execute("SHOW WAREHOUSES LIKE 'COMPUTE_WH'")
        whs = cursor.fetchall()
        if whs:
            for wh in whs:
                print(f"   • {wh[0]} (size: {wh[3]})")
        else:
            print("   (none - create with 'just titan-apply')")
        
        cursor.close()
        session.close()
        
        print()
        print("✅ Resource description complete")
        return 0
        
    except Exception as e:
        print(f"❌ Error: {e}")
        return 1

if __name__ == "__main__":
    resource = sys.argv[1] if len(sys.argv) > 1 else "SCHEMA_EVOLUTION_DB"
    sys.exit(main(resource))
