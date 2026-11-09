"""Load data/raw/intelligems/*.csv and data/raw/google_sheets/*.csv into RAW.INTELLIGEMS and RAW.GOOGLE_SHEETS
(tables from snowflake/04_raw_intelligems.sql).

Same loader as load_marketing.py: PUT to an internal stage, COPY INTO, the lab's audit columns, idempotent through
COPY's load metadata (a second run loads 0 rows). Signs in as the pipeline's service user, role LOADER on LOADING_WH.

Run:  python scripts/generate_intelligems_data.py && python scripts/load_intelligems.py     (repo root, .env sourced;
      the generator reads the Shopify and Recharge CSVs, so run generate_marketing_data.py and
      generate_recharge_data.py first on a fresh clone)
"""
from load_marketing import run

if __name__ == "__main__":
    run(ddl="04_raw_intelligems.sql", schemas=("intelligems", "google_sheets"), generator="generate_intelligems_data.py")
