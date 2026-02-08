"""
Main dlt pipeline – extracts weather data from Open-Meteo and loads into DuckDB.

Usage:
    # V1 schema (original fields)
    python -m extract.open_meteo_pipeline

    # V2 schema (evolved fields — adds precipitation, wind, UV)
    python -m extract.open_meteo_pipeline --schema-version 2

Environment variables (optional):
    DUCKDB_DATABASE: Path to DuckDB database file (default: ./data/schema_evolution.duckdb)
    DUCKDB_SCHEMA: DuckDB schema name (default: raw)
"""

import argparse
import os
import sys

import dlt
from dotenv import load_dotenv

# Allow running as `python -m extract.open_meteo_pipeline`
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from extract.sources.open_meteo import open_meteo_source  # noqa: E402


def build_pipeline() -> dlt.Pipeline:
    """Construct a dlt pipeline targeting DuckDB."""
    # Get database path from env or use default
    db_path = os.getenv("DUCKDB_DATABASE", "./data/schema_evolution.duckdb")
    
    # Ensure data directory exists
    os.makedirs(os.path.dirname(db_path) or ".", exist_ok=True)
    
    return dlt.pipeline(
        pipeline_name="open_meteo_to_duckdb",
        destination="duckdb",
        dataset_name=os.getenv("DUCKDB_SCHEMA", "raw"),
        pipelines_dir="dlt_pipelines",
    )


def run(schema_version: int = 1) -> None:
    """Execute the pipeline."""
    load_dotenv()

    pipeline = build_pipeline()
    source = open_meteo_source(schema_version=schema_version)

    info = pipeline.run(source)
    print("=" * 60)
    print("Pipeline load complete")
    print("=" * 60)
    print(info)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Run Open-Meteo → DuckDB dlt pipeline")
    parser.add_argument(
        "--schema-version",
        type=int,
        choices=[1, 2],
        default=1,
        help="Schema version: 1 = original fields, 2 = evolved fields (adds precip, wind, UV)",
    )
    args = parser.parse_args()
    run(schema_version=args.schema_version)


if __name__ == "__main__":
    main()
