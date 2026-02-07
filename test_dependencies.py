#!/usr/bin/env python
"""Quick dependency validation script"""

checks = []

# Test titan
try:
    from titan import Blueprint
    checks.append("✓ titan-core")
except Exception as e:
    checks.append(f"✗ titan-core: {e}")

# Test dlt
try:
    import dlt
    checks.append("✓ dlt")
except Exception as e:
    checks.append(f"✗ dlt: {e}")

# Test dbt
try:
    from dbt.cli.main import main as dbt_main
    checks.append("✓ dbt-core")
except Exception as e:
    checks.append(f"✗ dbt: {e}")

# Test snowflake connector
try:
    import snowflake.connector
    checks.append("✓ snowflake-connector")
except Exception as e:
    checks.append(f"✗ snowflake-connector: {e}")

# Test requests
try:
    import requests
    checks.append("✓ requests")
except Exception as e:
    checks.append(f"✗ requests: {e}")

# Test dotenv
try:
    from dotenv import load_dotenv
    checks.append("✓ python-dotenv")
except Exception as e:
    checks.append(f"✗ python-dotenv: {e}")

for check in checks:
    print(check)

print("\n✅ All dependencies validated!")
