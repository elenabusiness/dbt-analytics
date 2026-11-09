"""Load data/raw/*.csv into RAW.SHOP: PUT each file to the internal stage, then COPY INTO its table.

Idempotent by design: COPY INTO keeps 64 days of load metadata per table and skips a file it has already
loaded (same name + same checksum), so running this twice loads nothing the second time. That is one of the
exercises: prove it, then work out what FORCE = TRUE would do to the orders table.

Signs in as the pipeline's service user with its key pair (env: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER,
SNOWFLAKE_PRIVATE_KEY_PATH), as role LOADER on warehouse LOADING_WH.

Run:  python scripts/load_raw.py            (from the repo root, with .env sourced)
"""
import glob
import os
import re
import sys

import snowflake.connector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
TABLE_FOR = lambda f: re.sub(r"(_batch_\d+)?\.csv$", "", os.path.basename(f))  # orders_batch_2.csv -> orders


def connect(role="LOADER", warehouse="LOADING_WH"):
    return snowflake.connector.connect(
        account=os.environ["SNOWFLAKE_ACCOUNT"],
        user=os.environ["SNOWFLAKE_USER"],
        private_key_file=os.path.expanduser(os.environ["SNOWFLAKE_PRIVATE_KEY_PATH"]),
        role=role, warehouse=warehouse, database="RAW",
        session_parameters={"QUERY_TAG": "load_raw"},
        enable_server_session_keep_alive_auto_detection=False,
    )


def run(files=None):
    files = files or sorted(glob.glob(os.path.join(ROOT, "data", "raw", "*.csv")))
    if not files:
        sys.exit("no CSVs in data/raw - run: python scripts/generate_shop_data.py")
    with connect() as con:
        for cur in con.execute_string(open(os.path.join(ROOT, "snowflake", "01_raw_shop.sql")).read()):
            pass
        cur = con.cursor()
        for f in files:
            table = TABLE_FOR(f)
            cur.execute(f"put 'file://{f}' @raw.shop.shop_files/{table}/ auto_compress = true overwrite = false")
            # the column list is read from the table, so the CSV's columns map in order, then the audit columns
            cols = [r[0] for r in cur.execute(f"select column_name from raw.information_schema.columns "
                                              f"where table_schema = 'SHOP' and table_name = '{table.upper()}' "
                                              f"order by ordinal_position").fetchall()]
            data_cols = [c for c in cols if not c.startswith("_")]
            select = ", ".join(f"${i + 1}" for i in range(len(data_cols)))
            res = cur.execute(f"""
                copy into raw.shop.{table} ({", ".join(data_cols)}, _file_name, _file_row, _loaded_at)
                from (select {select}, metadata$filename, metadata$file_row_number, current_timestamp()
                      from @raw.shop.shop_files/{table}/)
                pattern = '.*{re.escape(os.path.basename(f))}.*'
                on_error = abort_statement""").fetchall()
            loaded = sum(r[3] for r in res if len(r) > 3 and isinstance(r[3], int))
            status = res[0][1] if res and len(res[0]) > 1 else res[0][0]
            print(f"{os.path.basename(f):28s} -> raw.shop.{table:14s} {status:>16s}  rows loaded: {loaded}")


if __name__ == "__main__":
    run(sys.argv[1:] or None)
