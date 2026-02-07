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
Snowflake + Iceberg       ← Storage with explicit schemas
        │
        ▼
    dbt Core              ← Transform, test & document
        │
        ▼
Docker + just + GH Actions ← Reproducibility & CI/CD
```

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
- Docker & Docker Compose
- [just](https://github.com/casey/just#installation) command runner (`brew install just`)
- A Snowflake account ([free trial](https://signup.snowflake.com/))

### ⚡ Start Here

**First time?** Use the [QUICK_START.md](QUICK_START.md) checklist (5 minutes) to verify prerequisites.

Then follow the step-by-step [SETUP_VALIDATION.md](SETUP_VALIDATION.md) guide for full setup.

### Setup

```bash
# 1. Clone the repo
git clone https://github.com/FilipeTheAnalyst/design-for-schema-evolution.git
cd design-for-schema-evolution

# 2. Copy env template and add your Snowflake credentials
just setup-env
# → Edit .env with your Snowflake account details

# 3. Set up Snowflake objects with Titan (Infrastructure as Code)
just install                           # Install Titan via uv
just titan-plan                        # See planned changes
just titan-apply                       # Apply infrastructure

# 4. Build the Docker image
just build

# 5. Run the full V1 pipeline
just pipeline-v1

# 6. Run V2 to see schema evolution in action
just pipeline-v2
```

### Run without Docker

```bash
just setup          # Install uv + deps locally
just extract-local  # Run dlt extraction
just dbt-build-local # Run dbt models + tests
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

## Snowflake free trial setup

1. Go to [signup.snowflake.com](https://signup.snowflake.com/)
2. Choose **Enterprise** edition (30-day free trial, no credit card)
3. Select a cloud provider and region
4. After account creation, note your **account identifier** (e.g. `abc12345.us-east-1`)
5. Add credentials to your `.env` file (copy from `.env.example`)
6. Run Titan to create database, schemas, and Iceberg tables:
   ```bash
   just titan-apply
   ```

Titan uses Infrastructure as Code (defined in [snowflake/manifest.py](snowflake/manifest.py)) to safely manage your Snowflake resources. See [Titan docs](https://titan.readthedocs.io/) for more.

---

## Project structure

```
├── snowflake/                          # Titan Infrastructure as Code
│   ├── manifest.py                     #   Database, schemas, warehouse, Iceberg tables
│   └── __init__.py
│
├── extract/                            # dlt extraction layer
│   ├── sources/
│   │   └── open_meteo.py               #   dlt source: V1 & V2 weather resources
│   └── open_meteo_pipeline.py          #   Pipeline: Open-Meteo → Snowflake
│
├── transform/                          # dbt project
│   ├── models/
│   │   ├── staging/            #   stg_weather_forecasts, stg_weather_hourly
│   │   ├── intermediate/       #   int_weather_daily_agg
│   │   └── marts/              #   fct_weather_summary
│   ├── macros/                 #   safe_cast, generate_schema_name
│   ├── seeds/                  #   location_lookup.csv
│   ├── tests/                  #   NULL-drift & schema evolution assertions
│   └── snapshots/              #   weather_forecast_snapshot
│
├── docs/                       # 5-part walkthrough
│   ├── 01_silent_schema_failures.md
│   ├── 02_symptom_level_mitigations.md
│   ├── 03_root_cause_analysis.md
│   ├── 04_designing_for_evolution.md
│   └── 05_production_architecture.md
│
├── .github/workflows/          # CI/CD
│   ├── ci.yml                  #   Lint, dbt compile, Docker build
│   └── deploy.yml              #   Scheduled extraction + transformation
│
├── Dockerfile                  # Containerized pipeline
├── docker-compose.yml          # Service definitions
├── titan.yml                   # Titan configuration
├── justfile                    # Command shortcuts
├── pyproject.toml              # Python project config
└── .env.example                # Environment variable template
```

---

## Just commands

| Command | Description |
|---------|-------------|
| `just setup` | Full local setup (env + uv + deps + Titan + dbt packages) |
| `just titan-plan` | Preview Snowflake infrastructure changes |
| `just titan-apply` | Create/update Snowflake resources (database, schemas, warehouse, Iceberg tables) |
| `just build` | Build Docker image |
| `just extract` | Run dlt extraction V1 (Docker) |
| `just extract-v2` | Run dlt extraction V2 — evolved schema (Docker) |
| `just dbt-build` | Run dbt models + tests (Docker) |
| `just pipeline-v1` | Full V1 pipeline: extract → seed → build |
| `just pipeline-v2` | Full V2 pipeline: extract evolved → build |
| `just demo` | Run V1 then V2 end-to-end |
| `just lint` | Lint Python code with ruff |
| `just clean` | Remove build artifacts |

Run `just` with no arguments to see all available commands.

---

## Schema evolution demo

### What happens

1. **V1 runs**: dlt loads temperature data into Snowflake. dbt builds models. Evolved columns (`precipitation_sum_mm`, `wind_speed_max_kmh`, `uv_index_max`) are `NULL`.

2. **V2 runs**: dlt detects new columns in the API response and adds them to Snowflake automatically. dbt rebuilds — evolved columns now have data.

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
| **Extract & Load** | [dlt (dlthub)](https://dlthub.com/) | Schema-aware ingestion into Snowflake |
| **Infrastructure** | [Titan](https://github.com/Titan-Systems/titan) | Infrastructure as Code for Snowflake |
| **Storage** | [Snowflake](https://www.snowflake.com/) + [Apache Iceberg](https://iceberg.apache.org/) | Warehouse with versioned, explicit schemas |
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
- Compiles dbt models (validates SQL)
- Builds Docker image

### Deploy (`.github/workflows/deploy.yml`)
- Triggered manually or on a daily schedule
- Runs dlt extraction → dbt seed → dbt build
- Supports V1 or V2 schema selection via workflow dispatch

**Required secrets:**
`SNOWFLAKE_ACCOUNT`, `SNOWFLAKE_USER`, `SNOWFLAKE_PASSWORD`, `SNOWFLAKE_ROLE`, `SNOWFLAKE_WAREHOUSE`, `SNOWFLAKE_DATABASE`

---

## Who this is for

- Analytics engineers working with semi-structured data
- Data engineers operating Snowflake in production
- Teams dealing with recurring schema-related incidents
- Anyone tired of "green pipelines, wrong data"

---

## License

MIT — use freely, adapt responsibly.
