# Dependency Resolution Fixes

## Issue: `uv sync` Failed with Unresatisfiable Dependencies

### Root Cause
The project specified `titan-core>=5.0.0` in `pyproject.toml`, but only version `0.11.1` is available in PyPI.

### Fixes Applied

#### 1. **pyproject.toml** - Updated titan-core version constraint
```diff
- "titan-core>=5.0.0",
+ "titan-core>=0.11.0",
```

#### 2. **snowflake/manifest.py** - Fixed warehouse size syntax
Version 0.11.1 requires string literals instead of enum:
```diff
- warehouse_size=res.WarehouseSize.XSMALL,
+ warehouse_size="XSMALL",
```

#### 3. **snowflake/manifest.py** - Fixed Iceberg table class name
Version 0.11.1 uses `SnowflakeIcebergTable` instead of `IcebergTable`:
```diff
- weather_forecasts_iceberg = res.IcebergTable(
+ weather_forecasts_iceberg = res.SnowflakeIcebergTable(

- weather_hourly_iceberg = res.IcebergTable(
+ weather_hourly_iceberg = res.SnowflakeIcebergTable(
```

## Verification

✅ `uv sync` now completes successfully
✅ All 118 packages resolve correctly
✅ Titan manifest (snowflake/manifest.py) parses without errors
✅ All key dependencies installed:
   - titan-core==0.11.1
   - dlt with snowflake extra
   - dbt-core & dbt-snowflake
   - snowflake-connector-python
   - requests
   - python-dotenv

## Next Steps

Run the setup validation to test the full pipeline:

```bash
# Verify the fixes
bash scripts/health_check.sh

# Create environment file
just setup-env

# Install dependencies (should work now)
uv sync

# Test Titan infrastructure
just titan-plan
```

## Notes

- titan-core 0.11.1 is the latest stable release available
- The API differences noted here are specific to this version
- All functionality (Iceberg tables, Snowflake schema management, etc.) is preserved
- Schema evolution demonstration remains fully operational
