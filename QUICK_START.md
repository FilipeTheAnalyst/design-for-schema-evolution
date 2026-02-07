# Quick Start Checklist

Use this quick checklist **before** running the project to ensure all prerequisites are met.

## ⚡ 5-Minute Pre-Flight Check

```bash
# 1. Python version (3.10+)
python --version

# 2. uv installed
uv --version

# 3. Docker & Docker Compose running
docker ps
docker compose --version

# 4. just command runner
just --version

# 5. git (already have it)
git --version

# 6. Snowflake account created
# Go to: https://signup.snowflake.com/
# Choose: Enterprise edition (30-day free trial)
# Note your account identifier (e.g., abc12345.us-east-1)
```

## 📋 Setup Steps (In Order)

| # | Step | Command | Expected Result |
|---|------|---------|-----------------|
| 1 | Environment | `just setup-env` | `.env` file created |
| 2 | Edit `.env` | `nano .env` | Snowflake credentials filled in |
| 3 | Install deps | `uv sync` | `.venv` created with packages |
| 4 | Plan infra | `just titan-plan` | Shows Snowflake resources to create |
| 5 | Create infra | `just titan-apply` | Database, schemas, warehouse created |
| 6 | dbt packages | `just dbt-deps` | dbt_utils, dbt_expectations installed |
| 7 | Extract V1 | `just extract-local` | Data loaded into RAW.WEATHER_FORECASTS |
| 8 | Build dbt | `just dbt-build-local` | All models + tests pass |
| 9 | Extract V2 | `just extract-local version=2` | Schema evolved (new columns added) |
| 10 | Full demo | `just demo` | V1 → V2 story complete! |

## 🆘 Before Asking for Help

If something fails, check:

1. **`uv sync` fails?**
   - Running Python 3.10+? → `python --version`
   - Using correct Python? → `uv sync --python 3.11`

2. **Snowflake connection fails?**
   - Credentials correct in `.env`? → `cat .env | grep SNOWFLAKE_`
   - Account identifier format correct? → Should be `abc12345.us-east-1` (not full URL)

3. **Titan apply fails?**
   - Snowflake account active & accessible?
   - User has SYSADMIN role?
   - Try: `just titan-plan` (should show changes, not errors)

4. **Docker build fails?**
   - Docker daemon running? → `docker ps`
   - Disk space available? → `df -h`
   - Try rebuild: `docker build --no-cache -t schema-evolution:latest .`

5. **dbt compile fails?**
   - Profiles correct? → `cat transform/profiles.yml`
   - Packages installed? → `just dbt-deps`
   - Try: `cd transform && dbt debug --profiles-dir .`

## 📚 Full Documentation

For detailed step-by-step validation:
→ **[SETUP_VALIDATION.md](SETUP_VALIDATION.md)**

## ✅ Success!

All 10 steps completed with ✓? **Your project is ready!**

Next: Explore the [docs/](docs/) folder or run `just` to see all available commands.
