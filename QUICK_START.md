# Quick Start Checklist

Use this quick checklist **before** running the project to ensure all prerequisites are met.

## ⚡ 5-Minute Pre-Flight Check

```bash
# 1. Python version (3.10-3.13)
python3 --version

# 2. uv installed
uv --version

# 3. Docker & Docker Compose running
docker ps
docker compose --version

# 4. just command runner
just --version

# 5. git (already have it)
git --version
```

## 📋 Setup Steps (In Order)

| # | Step | Command | Expected Result |
|---|------|---------|-----------------|
| 1 | Clone | `git clone ...` | Project directory ready |
| 2 | Environment | `just setup-env` | `.env` file created with defaults |
| 3 | Install deps | `just install` | `.venv` created with dlt, dbt-duckdb, duckdb |
| 4 | dbt packages | `just dbt-deps` | dbt_utils, dbt_expectations installed |
| 5 | Build Docker | `just build` | Docker image built |
| 6 | Start LocalStack | `just localstack-up` | S3 emulation ready on port 4566 |
| 7 | Extract V1 | `just extract` | Data loaded into DuckDB RAW schema |
| 8 | Build dbt | `just dbt-build` | All models + tests pass |
| 9 | Extract V2 | `just extract-v2` | Schema evolved (new columns added) |
| 10 | Full demo | `just pipeline-v2` | V1 → V2 story complete! |

## 🆘 Before Asking for Help

If something fails, check:

1. **`uv sync` fails?**
   - Running Python 3.10-3.13? → `python3 --version`
   - (Python 3.14+ has compatibility issues with dbt)
   - Using correct Python? → `uv sync --python 3.13`

2. **Docker build fails?**
   - Docker daemon running? → `docker ps`
   - Disk space available? → `df -h`
   - Try rebuild: `docker build --no-cache -t schema-evolution:latest .`

3. **LocalStack won't start?**
   - Docker running? → `docker ps`
   - Port 4566 available? → `netstat -an | grep 4566`
   - Try: `just localstack-down && sleep 5 && just localstack-up`

4. **dbt compile fails?**
   - Profiles correct? → `cat transform/profiles.yml`
   - Packages installed? → `just dbt-deps`
   - Try: `cd transform && dbt debug --profiles-dir . --target dev`

5. **DuckDB file locked?**
   - Previous process still running?
   - Clean & retry: `just db-clean && just extract`

## 📚 Full Documentation

For detailed step-by-step validation:
→ **[SETUP_VALIDATION.md](SETUP_VALIDATION.md)**

## ✅ Success!

All 10 steps completed with ✓? **Your project is ready!**

Next: Explore the [docs/](docs/) folder or run `just` to see all available commands.
