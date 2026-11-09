"""Load data/raw/recharge/*.csv into RAW.RECHARGE (tables from snowflake/03_raw_recharge.sql).

Same loader as load_marketing.py: PUT to an internal stage, COPY INTO with parse_json() for VARIANT columns, the
lab's audit columns, idempotent through COPY's load metadata (a second run loads 0 rows). Signs in as the pipeline's
service user, role LOADER on LOADING_WH.

Run:  python scripts/generate_recharge_data.py && python scripts/load_recharge.py     (repo root, .env sourced;
      generate_recharge_data.py reads the Shopify CSVs, so run generate_marketing_data.py first on a fresh clone)
"""
from load_marketing import run

if __name__ == "__main__":
    run(ddl="03_raw_recharge.sql", schemas=("recharge",), generator="generate_recharge_data.py")
