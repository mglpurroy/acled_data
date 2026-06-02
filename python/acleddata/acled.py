import os
import tempfile
from typing import Optional

import requests
import pandas as pd


VOLUME_PATH = (
    "/Volumes/prd_datascience_compoundriskmonitor/volumes"
    "/compoundriskmonitor/fcvriskdashboard/acled_data_current.csv"
)


def acled_auth(host: str, token: str) -> None:
    """Set Databricks credentials for the session.

    Alternatively set DATABRICKS_HOST and DATABRICKS_TOKEN
    as environment variables.
    """
    os.environ["DATABRICKS_HOST"] = host
    os.environ["DATABRICKS_TOKEN"] = token


def read_acled(
    country: Optional[str] = None,
    countries: Optional[list[str]] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
) -> pd.DataFrame:
    """Read ACLED conflict data from Databricks.

    Credentials must be set via acled_auth() or environment variables:
        DATABRICKS_HOST and DATABRICKS_TOKEN

    Args:
        country:    Single country name (e.g. "Afghanistan")
        countries:  List of country names
        start_date: Start date as "YYYY-MM-DD" string
        end_date:   End date as "YYYY-MM-DD" string

    Returns:
        pandas DataFrame with ACLED event data
    """
    host  = os.environ.get("DATABRICKS_HOST", "")
    token = os.environ.get("DATABRICKS_TOKEN", "")

    if not host or not token:
        raise EnvironmentError(
            "Credentials not set. Run acled_auth(host, token) or set "
            "DATABRICKS_HOST and DATABRICKS_TOKEN environment variables."
        )

    print("Downloading ACLED dataset from Databricks...")

    url = f"{host.rstrip('/')}/api/2.0/fs/files{VOLUME_PATH}"

    with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as tmp:
        tmp_path = tmp.name

    try:
        with requests.get(
            url,
            headers={"Authorization": f"Bearer {token}"},
            stream=True,
            timeout=300,
        ) as r:
            r.raise_for_status()
            with open(tmp_path, "wb") as f:
                for chunk in r.iter_content(chunk_size=8192):
                    f.write(chunk)

        df = pd.read_csv(tmp_path, low_memory=False)
    finally:
        os.unlink(tmp_path)

    # Apply filters locally
    all_countries = list(filter(None, [country] + (countries or [])))
    if all_countries:
        df = df[df["country"].isin(all_countries)]
    if start_date:
        df = df[pd.to_datetime(df["event_date"]) >= pd.to_datetime(start_date)]
    if end_date:
        df = df[pd.to_datetime(df["event_date"]) <= pd.to_datetime(end_date)]

    print(f"Loaded {len(df):,} records.")
    return df
