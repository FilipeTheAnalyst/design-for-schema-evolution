# Design for Schema Evolution

A hands-on data engineering project that demonstrates how schema evolution impacts real-world analytics pipelines — and how to design for it instead of reacting to failures.

**Data source:** [Open-Meteo API](https://open-meteo.com/) — free global weather forecasts, no API key required.

---

## Architecture

```
Open-Meteo API (JSON)
        │
        ▼
   dlt (dlthub)          ← Extract & Load
        │
        ▼
   DuckDB (local)        ← Storage with explicit schemas
        │
        ▼
  LocalStack S3          ← Iceberg table storage (optional)
        │
        ▼
    dbt Core             ← Transform, test & document
        │
        ▼
Docker + just + GH Actions ← Reproducibility & CI/CD
```

**Key advantages:**
- ✅ Zero external dependencies (no Snowflake account needed)
- ✅ Fast local development (in-process DuckDB)
- ✅ Full schema evolution testing with Iceberg
- ✅ LocalStack S3 for realistic S3-backed Iceberg tables
- ✅ Reproducible CI/CD with Docker Compose

## The story

1. **V1 extraction** loads temperature and humidity from Open-Meteo
2. **V2 extraction** adds precipitation, wind speed, and UV index — simulating a real upstream schema change
3. dbt models handle both versions gracefully with defensive SQL
4. Iceberg tables enforce explicit, versioned schemas at the storage layer
5. Tests catch silent NULL drift before dashboards break

---

## Quick start

### Prerequisites

- Python 3.10+
- [uv](https://docs.astral.sh/uv/) package manager (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- Docker & Docker Compose (for containerized runs)
- [just](https://github.com/casey/just#installation) command runner (`brew install just`)
- DuckDB will be installed automatically via `uv sync`

**✅ No Snowflake account, no paid services — everything is local!**

### ⚡ Start Here

```bash
# 1. Clone the repo
git clone https://github.com/FilipeTheAnalyst/design-for-schema-evolution.git
cd design-for-schema-evolution

# 2. Copy env template (defaults are set for LocalStack)
just setup-env

# 3. Full setup: install deps, dbt packages
just install && just dbt-deps

# 4. Build Docker image
just build

# 5. Start LocalStack (S3 emulation)
just localstack-up

# 6. Run the full V1 pipeline
just pipeline-v1

# 7. Run V2 to see schema evolution in action
just pipeline-v2
```

### Run without Docker (local dev)

```bash
just setup                # Install uv + deps locally
just extract-local        # Run dlt extraction → DuckDB
cd transform && dbt build --profiles-dir . --target dev  # Run dbt models + tests
```

### Access your data

```bash
# Open interactive DuckDB CLI
just duckdb

# Show tables/schemas in DuckDB
just db-info
```

---

## Setup Validation

To ensure the entire project works end-to-end, follow the **[SETUP_VALIDATION.md](SETUP_VALIDATION.md)** guide. It provides:

- ✅ Step-by-step validation of each component
- ✅ Prerequisites checklist
- ✅ Troubleshooting for common issues
- ✅ Success criteria (11-step validation)

**Start here** if you're running the project for the first time.

### Project Health Status

**[VALIDATION_REPORT.md](VALIDATION_REPORT.md)** provides:
- ✅ Full validation results (46/49 checks passing - 93%)
- ✅ Component-by-component status
- ✅ Confidence assessment for each layer
- ✅ Pre-setup state analysis
- ✅ Next steps and recommendations

**Check this** to understand the current state of the project before running setup.

---

## Project structure

```
├── extract/                            # dlt extraction layer
│   ├── sources/
│   │   └── open_meteo.py               #   dlt source: V1 & V2 weather resources
│   └── open_meteo_pipeline.py          #   Pipeline: Open-Meteo → DuckDB
│
├── transform/                          # dbt project (DuckDB adapter)
│   ├── models/
│   │   ├── staging/            #   stg_weather_forecasts, stg_weather_hourly
│   │   ├── intermediate/       #   int_weather_daily_agg
│   │   └── marts/              #   fct_weather_summary (incremental, Iceberg-ready)
│   ├── macros/                 #   safe_cast, generate_schema_name
│   ├── seeds/                  #   location_lookup.csv
│   ├── tests/                  #   NULL-drift & schema evolution assertions
│   ├── snapshots/              #   weather_forecast_snapshot
│   └── profiles.yml            #   DuckDB adapter config
│
├── docs/                       # 5-part walkthrough on schema evolution
│   ├── 01_silent_schema_failures.md
│   ├── 02_symptom_level_mitigations.md
│   ├── 03_root_cause_analysis.md
│   ├── 04_designing_for_evolution.md
│   └── 05_production_architecture.md
│
├── scripts/
│   └── init-localstack.sh      # LocalStack S3 bucket initialization
│
├── data/                       # Local DuckDB database (git-ignored)
│   └── schema_evolution.duckdb
│
├── .github/workflows/          # CI/CD
│   ├── ci.yml                  #   Lint, dbt compile (DuckDB), Docker build
│   └── deploy.yml              #   Extraction + transformation (Docker Compose)
│
├── dlt_pipelines/              # dlt pipeline state (git-ignored)
├── Dockerfile                  # Containerized pipeline
├── docker-compose.yml          # LocalStack + DuckDB services
├── justfile                    # Command shortcuts
├── pyproject.toml              # Python project config (dlt, dbt-duckdb, duckdb, boto3)
└── .env.example                # Environment variable template (LocalStack defaults)
```

---

## Just commands

| Command | Description |
|---------|-------------|
| `just setup` | Full local setup (env + uv + deps + dbt packages) |
| `just localstack-up` | Start LocalStack S3 emulation |
| `just localstack-down` | Stop LocalStack |
| `just build` | Build Docker image |
| `just extract` | Run dlt extraction V1 → DuckDB (Docker) |
| `just extract-v2` | Run dlt extraction V2 — evolved schema (Docker) |
| `just extract-local` | Run extraction without Docker |
| `just dbt-run` | Run dbt models (Docker) |
| `just dbt-build` | Run dbt models + tests (Docker) |
| `just pipeline-v1` | Full V1 pipeline: extract → seed → build |
| `just pipeline-v2` | Full V2 pipeline: extract evolved → build |
| `just duckdb` | Open interactive DuckDB CLI |
| `just db-clean` | Delete local DuckDB database |
| `just db-info` | Show DuckDB tables & schemas |
| `just lint` | Lint Python code with ruff |

Run `just` with no arguments to see all available commands.

---

## Schema evolution demo

### What happens

1. **V1 runs**: dlt loads temperature data into DuckDB. dbt builds models. Evolved columns (`precipitation_sum_mm`, `wind_speed_max_kmh`, `uv_index_max`) are `NULL`.

2. **V2 runs**: dlt detects new columns in the API response and adds them to DuckDB. dbt rebuilds — evolved columns now have data.

3. The `fct_weather_summary` mart includes a `schema_version` column so analysts can see which data generation they're working with.

### Key patterns demonstrated

- **dlt**: Automatic schema inference and evolution at ingestion
- **Iceberg**: Explicit, versioned schemas with safe `ADD COLUMN`
- **dbt `safe_cast` macro**: Handles columns that may not exist yet
- **dbt tests**: Catches silent NULL drift in critical fields
- **dbt snapshots**: Tracks how data changes over time

---

## What this project covers

| Part | Topic | Doc |
|------|-------|-----|
| 1 | Silent schema failures | [docs/01](docs/01_silent_schema_failures.md) |
| 2 | Symptom-level mitigations | [docs/02](docs/02_symptom_level_mitigations.md) |
| 3 | Root cause analysis | [docs/03](docs/03_root_cause_analysis.md) |
| 4 | Designing for evolution (Iceberg) | [docs/04](docs/04_designing_for_evolution.md) |
| 5 | Production architecture | [docs/05](docs/05_production_architecture.md) |

---

## Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| **API** | [Open-Meteo](https://open-meteo.com/) | Free weather forecast data (no auth) |
| **Extract & Load** | [dlt (dlthub)](https://dlthub.com/) | Schema-aware ingestion into DuckDB |
| **Storage** | [DuckDB](https://duckdb.org/) | Local OLAP database (no server, no setup) |
| **S3 Storage** | [LocalStack](https://localstack.cloud/) | AWS S3 emulation (for Iceberg tables) |
| **S3 Access** | [boto3](https://boto3.amazonaws.com/) | AWS SDK (works with LocalStack) |
| **DuckDB Adapter** | [dbt-duckdb](https://github.com/dbt-labs/dbt-duckdb) | dbt adapter for DuckDB |
| **Transform** | [dbt Core](https://www.getdbt.com/) | SQL models, tests, snapshots, docs |
| **Package manager** | [uv](https://docs.astral.sh/uv/) | Fast Python package installer & resolver |
| **Containerization** | [Docker](https://www.docker.com/) | Reproducible environment |
| **Task runner** | [just](https://github.com/casey/just) | Simple command shortcuts |
| **CI/CD** | [GitHub Actions](https://github.com/features/actions) | Automated lint, compile, deploy |

---

## GitHub Actions

### CI (`.github/workflows/ci.yml`)
- Triggers on push/PR to `develop` and `main`
- Lints Python with ruff
- Compiles dbt models against DuckDB (validates SQL)
- Builds Docker image

### Deploy (`.github/workflows/deploy.yml`)
- Triggered manually or on a daily schedule
- Runs dlt extraction → dbt seed → dbt build (using Docker Compose + LocalStack)
- Supports V1 or V2 schema selection via workflow dispatch
- All tools run locally in containers — no external services needed

**No secrets required** — everything runs in-process on GitHub Actions runners!

---

## Who this is for

- Analytics engineers learning about schema evolution
- Data engineers designing resilient pipelines
- Teams building local-first, reproducible data stacks
- Anyone tired of "green pipelines, wrong data"

---

## License

MIT — use freely, adapt responsibly.
