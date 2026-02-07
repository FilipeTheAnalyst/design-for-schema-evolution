"""
Open-Meteo dlt source.

Extracts weather forecast data from the Open-Meteo API (https://open-meteo.com/).
No API key required — free and open for non-commercial use.

This module defines two dlt resources:
  1. weather_forecasts  — daily forecast summaries per location
  2. weather_hourly     — hourly forecast detail per location

The schema intentionally starts simple and can evolve over time
(e.g. adding wind, precipitation, UV index) to demonstrate how
schema evolution propagates through the pipeline.
"""

from datetime import datetime, timezone

import dlt
import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

BASE_URL = "https://api.open-meteo.com/v1/forecast"

# Default locations – extend this list to ingest more cities
DEFAULT_LOCATIONS: list[dict] = [
    {"city": "New York", "latitude": 40.7128, "longitude": -74.0060},
    {"city": "London", "latitude": 51.5074, "longitude": -0.1278},
    {"city": "Tokyo", "latitude": 35.6762, "longitude": 139.6503},
    {"city": "Sydney", "latitude": -33.8688, "longitude": 151.2093},
    {"city": "São Paulo", "latitude": -23.5505, "longitude": -46.6333},
]

# ── V1 params (start here) ────────────────────────────────────────────────
# These are the "original" fields. Later we add more to simulate evolution.
HOURLY_PARAMS_V1 = [
    "temperature_2m",
    "relative_humidity_2m",
    "apparent_temperature",
]

DAILY_PARAMS_V1 = [
    "temperature_2m_max",
    "temperature_2m_min",
    "apparent_temperature_max",
    "apparent_temperature_min",
    "sunrise",
    "sunset",
]

# ── V2 params (schema evolution – add these later) ────────────────────────
HOURLY_PARAMS_V2 = HOURLY_PARAMS_V1 + [
    "precipitation",
    "wind_speed_10m",
    "wind_direction_10m",
]

DAILY_PARAMS_V2 = DAILY_PARAMS_V1 + [
    "precipitation_sum",
    "wind_speed_10m_max",
    "uv_index_max",
]


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _fetch_forecast(
    latitude: float,
    longitude: float,
    hourly_params: list[str],
    daily_params: list[str],
) -> dict:
    """Call the Open-Meteo Forecast API and return the raw JSON response."""
    params = {
        "latitude": latitude,
        "longitude": longitude,
        "hourly": ",".join(hourly_params),
        "daily": ",".join(daily_params),
        "timezone": "auto",
    }
    resp = requests.get(BASE_URL, params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


# ---------------------------------------------------------------------------
# dlt resources
# ---------------------------------------------------------------------------

@dlt.resource(
    name="weather_forecasts",
    write_disposition="replace",
    columns={"_dlt_load_id": {"data_type": "text"}},
)
def weather_forecasts(
    locations: list[dict] = DEFAULT_LOCATIONS,
    daily_params: list[str] = DAILY_PARAMS_V1,
    hourly_params: list[str] = HOURLY_PARAMS_V1,
):
    """
    Yield one row per (location, forecast_date) with daily summary fields.

    The set of columns depends on which `daily_params` you pass in.
    Start with V1, then switch to V2 to trigger schema evolution.
    """
    ingested_at = datetime.now(timezone.utc).isoformat()

    for loc in locations:
        data = _fetch_forecast(
            loc["latitude"],
            loc["longitude"],
            hourly_params=hourly_params,
            daily_params=daily_params,
        )

        daily = data.get("daily", {})
        dates = daily.get("time", [])

        for i, date_str in enumerate(dates):
            row = {
                "city": loc["city"],
                "latitude": loc["latitude"],
                "longitude": loc["longitude"],
                "forecast_date": date_str,
                "ingested_at": ingested_at,
            }
            # Dynamically add whatever daily params were returned
            for param in daily_params:
                values = daily.get(param, [])
                row[param] = values[i] if i < len(values) else None

            yield row


@dlt.resource(
    name="weather_hourly",
    write_disposition="replace",
    columns={"_dlt_load_id": {"data_type": "text"}},
)
def weather_hourly(
    locations: list[dict] = DEFAULT_LOCATIONS,
    hourly_params: list[str] = HOURLY_PARAMS_V1,
    daily_params: list[str] = DAILY_PARAMS_V1,
):
    """
    Yield one row per (location, timestamp) with hourly detail fields.

    Like `weather_forecasts`, the column set grows when you switch
    from V1 to V2 params — a concrete example of schema evolution.
    """
    ingested_at = datetime.now(timezone.utc).isoformat()

    for loc in locations:
        data = _fetch_forecast(
            loc["latitude"],
            loc["longitude"],
            hourly_params=hourly_params,
            daily_params=daily_params,
        )

        hourly = data.get("hourly", {})
        timestamps = hourly.get("time", [])

        for i, ts in enumerate(timestamps):
            row = {
                "city": loc["city"],
                "latitude": loc["latitude"],
                "longitude": loc["longitude"],
                "timestamp": ts,
                "ingested_at": ingested_at,
            }
            for param in hourly_params:
                values = hourly.get(param, [])
                row[param] = values[i] if i < len(values) else None

            yield row


# ---------------------------------------------------------------------------
# dlt source (bundles both resources)
# ---------------------------------------------------------------------------

@dlt.source(name="open_meteo")
def open_meteo_source(
    locations: list[dict] = DEFAULT_LOCATIONS,
    schema_version: int = 1,
):
    """
    dlt source that bundles daily and hourly weather resources.

    Args:
        locations: List of dicts with city, latitude, longitude.
        schema_version: 1 = original fields, 2 = evolved fields.
    """
    hourly = HOURLY_PARAMS_V1 if schema_version == 1 else HOURLY_PARAMS_V2
    daily = DAILY_PARAMS_V1 if schema_version == 1 else DAILY_PARAMS_V2

    return [
        weather_forecasts(locations=locations, daily_params=daily, hourly_params=hourly),
        weather_hourly(locations=locations, hourly_params=hourly, daily_params=daily),
    ]
