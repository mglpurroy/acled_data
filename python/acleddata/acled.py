import os
import time
import tempfile
from datetime import date
from typing import Optional

import requests
import pandas as pd


DELTA_TABLE = (
    "prd_datascience_compoundriskmonitor."
    "compoundriskmonitor.acled"
)


def acled_auth(host: str, token: str, warehouse_id: str) -> None:
    """Set Databricks credentials for the session.

    Alternatively set environment variables:
        DATABRICKS_HOST, DATABRICKS_TOKEN, DATABRICKS_WAREHOUSE_ID
    """
    os.environ["DATABRICKS_HOST"] = host
    os.environ["DATABRICKS_TOKEN"] = token
    os.environ["DATABRICKS_WAREHOUSE_ID"] = warehouse_id


def read_acled(
    country: Optional[str] = None,
    countries: Optional[list[str]] = None,
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
) -> pd.DataFrame:
    """Read ACLED conflict data from Databricks Delta table.

    Credentials must be set via acled_auth() or environment variables:
        DATABRICKS_HOST, DATABRICKS_TOKEN, DATABRICKS_WAREHOUSE_ID

    Args:
        country:    Single country name (e.g. "Afghanistan")
        countries:  List of country names
        start_date: Start date as "YYYY-MM-DD" string
        end_date:   End date as "YYYY-MM-DD" string

    Returns:
        pandas DataFrame with ACLED event data
    """
    host         = os.environ.get("DATABRICKS_HOST", "")
    token        = os.environ.get("DATABRICKS_TOKEN", "")
    warehouse_id = os.environ.get("DATABRICKS_WAREHOUSE_ID", "")

    if not host or not token or not warehouse_id:
        raise EnvironmentError(
            "Credentials not set. Run acled_auth(host, token, warehouse_id) "
            "or set environment variables:\n"
            "  DATABRICKS_HOST\n"
            "  DATABRICKS_TOKEN\n"
            "  DATABRICKS_WAREHOUSE_ID"
        )

    sql = _build_query(country, countries, start_date, end_date)
    print(f"Running: {sql}")
    return _run_sql(sql, host, token, warehouse_id)


def _build_query(country, countries, start_date, end_date):
    filters = []

    all_countries = list(filter(None, [country] + (countries or [])))
    if all_countries:
        in_list = ", ".join(f"'{c}'" for c in all_countries)
        filters.append(f"country IN ({in_list})")
    if start_date:
        filters.append(f"event_date >= '{start_date}'")
    if end_date:
        filters.append(f"event_date <= '{end_date}'")

    where = f"WHERE {' AND '.join(filters)}" if filters else ""
    return f"SELECT * FROM {DELTA_TABLE} {where}".strip()


def _run_sql(sql, host, token, warehouse_id):
    headers = {"Authorization": f"Bearer {token}"}
    url = f"{host.rstrip('/')}/api/2.0/sql/statements"

    resp = requests.post(url, headers=headers, json={
        "warehouse_id": warehouse_id,
        "statement":    sql,
        "wait_timeout": "50s",
        "disposition":  "EXTERNAL_LINKS",
        "format":       "CSV",
    }).json()

    # Poll if still running
    while resp["status"]["state"] in ("PENDING", "RUNNING"):
        time.sleep(2)
        resp = requests.get(
            f"{url}/{resp['statement_id']}",
            headers=headers
        ).json()

    if resp["status"]["state"] != "SUCCEEDED":
        raise RuntimeError(
            f"Query failed: {resp['status']['error']['message']}"
        )

    # Download each chunk and combine
    chunks = []
    for link in resp["result"]["external_links"]:
        with tempfile.NamedTemporaryFile(suffix=".csv", delete=False) as tmp:
            tmp_path = tmp.name
        try:
            chunk_resp = requests.get(link["external_link"], stream=True)
            with open(tmp_path, "wb") as f:
                for chunk in chunk_resp.iter_content(chunk_size=8192):
                    f.write(chunk)
            chunks.append(pd.read_csv(tmp_path, low_memory=False))
        finally:
            os.unlink(tmp_path)

    df = pd.concat(chunks, ignore_index=True) if chunks else pd.DataFrame()
    print(f"Loaded {len(df):,} records.")
    return df
