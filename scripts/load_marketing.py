"""Load data/raw/shopify/*.csv and data/raw/meta_ads/*.csv into RAW.SHOPIFY and RAW.META_ADS.

Same pattern as load_raw.py (PUT to an internal stage, COPY INTO, audit columns, idempotent through COPY's load
metadata), with one addition: columns declared VARIANT in snowflake/02_raw_shopify_meta.sql are parsed from the
CSV's JSON text with parse_json() inside the COPY, so they land as real semi-structured values.

Signs in as the pipeline's service user (env: SNOWFLAKE_ACCOUNT, SNOWFLAKE_USER, SNOWFLAKE_PRIVATE_KEY_PATH), as role
LOADER on LOADING_WH.

Run:  python scripts/generate_marketing_data.py && python scripts/load_marketing.py     (repo root, .env sourced)
"""
import glob
import os
import sys

from load_raw import ROOT, connect

SCHEMAS = ("shopify", "meta_ads")


def run(ddl="02_raw_shopify_meta.sql", schemas=SCHEMAS, generator="generate_marketing_data.py"):
    with connect() as con:
        for _ in con.execute_string(open(os.path.join(ROOT, "snowflake", ddl)).read()):
            pass
        cur = con.cursor()
        for schema in schemas:
            files = sorted(glob.glob(os.path.join(ROOT, "data", "raw", schema, "*.csv")))
            if not files:
                sys.exit(f"no CSVs in data/raw/{schema} - run: python scripts/{generator}")
            for f in files:
                table = os.path.basename(f)[:-4]
                fq = f'raw.{schema}."{table.upper()}"'           # quoted: one of these tables is called ORDER
                cur.execute(f"put 'file://{f}' @raw.{schema}.files/{table}/ auto_compress = true overwrite = false")
                cols = cur.execute(f"select column_name, data_type from raw.information_schema.columns "
                                   f"where table_schema = '{schema.upper()}' and table_name = '{table.upper()}' "
                                   f"order by ordinal_position").fetchall()
                data_cols = [(c, t) for c, t in cols if c not in ("_FILE_NAME", "_FILE_ROW", "_LOADED_AT")]
                select = ", ".join(f"parse_json(${i + 1})" if t == "VARIANT" else f"${i + 1}" for i, (c, t) in enumerate(data_cols))
                res = cur.execute(f"""
                    copy into {fq} ({", ".join(c for c, _ in data_cols)}, _file_name, _file_row, _loaded_at)
                    from (select {select}, metadata$filename, metadata$file_row_number, current_timestamp()
                          from @raw.{schema}.files/{table}/)
                    on_error = abort_statement""").fetchall()
                loaded = sum(r[3] for r in res if len(r) > 3 and isinstance(r[3], int))
                status = res[0][1] if res and len(res[0]) > 1 else res[0][0]
                print(f"{schema}/{table + '.csv':28s} -> {fq:34s} {status:>16s}  rows loaded: {loaded}")


if __name__ == "__main__":
    run()
