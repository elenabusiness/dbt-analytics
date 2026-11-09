# Porting a Dataform + BigQuery pipeline to dbt + Snowflake

Keep this open next to the old repo while you port. Two halves: the **framework** (Dataform → dbt) and the
**SQL dialect** (BigQuery → Snowflake). The dialect rows marked ✓ were run on your trial account on 4 Nov 2026.

## 1. Framework: Dataform → dbt

| Dataform | dbt | Notes |
|---|---|---|
| `workflow_settings.yaml` (`defaultProject`, `defaultDataset`, `vars`) | `dbt_project.yml` + `profiles.yml` | connection lives in `profiles.yml`; `vars` move to `vars:` in `dbt_project.yml` |
| `definitions/**/*.sqlx` | `models/**/*.sql` | one file = one model, file name = model name |
| `config { type: "table" }` | `{{ config(materialized='table') }}` | or set it per folder in `dbt_project.yml` (`+materialized:`) |
| `type: "view"` | `materialized='view'` | |
| `type: "incremental"` | `materialized='incremental'` | |
| `uniqueKey: ["id"]` | `unique_key='id'` | with a unique key, dbt-snowflake MERGEs (default strategy `merge`) |
| `${when(incremental(), "where ...")}` / `if (incremental())` | `{% if is_incremental() %} where ... {% endif %}` | |
| `${self()}` | `{{ this }}` | |
| `${ref("model")}` | `{{ ref('model') }}` | |
| `type: "declaration"` (a source table) | `sources:` in a `.yml` + `{{ source('name', 'table') }}` | add `freshness` while you are there |
| `${ref("dataset", "table")}` on a declaration | `{{ source('dataset', 'table') }}` | |
| `type: "assertion"` file | a singular test in `tests/*.sql` | returns the bad rows; zero rows = pass |
| `assertions: { uniqueKey, nonNull }` | `data_tests: [unique, not_null]` on the column in `.yml` | |
| `assertions: { rowConditions: [...] }` | `dbt_utils.expression_is_true` | |
| `type: "operations"` | a macro run with `dbt run-operation`, or a `pre_hook`/`post_hook` | |
| `pre_operations { }` / `post_operations { }` | `pre_hook=` / `post_hook=` in `config()` | |
| `includes/*.js` constants and functions | `macros/*.sql` (Jinja) and `vars` | JavaScript becomes Jinja |
| `js { }` block inside a SQLX | Jinja `{% set %}` / `{% for %}` in the model | |
| `dependencies: ["x"]` | just `ref()` it; or `-- depends_on: {{ ref('x') }}` | |
| `tags: ["daily"]` + run by tag | `tags` config + `dbt build -s tag:daily` | |
| `schema: "x"` / `database: "y"` | `schema=` / `database=` config | the final name comes from `generate_schema_name` (see `macros/`) |
| `description` + `columns: {}` | `description:` + `columns:` in `.yml` | |
| `bigquery: { partitionBy, clusterBy }` | `cluster_by=[...]` | Snowflake has no user partitions: it micro-partitions automatically |
| `dataform compile` / `run` | `dbt compile` / `dbt build` | `build` = run + test + snapshot + seed in DAG order |
| Dataform release + workflow configurations (schedules) | the Airflow DAG (`airflow/dags/`) | |

## 2. Dialect: BigQuery SQL → Snowflake SQL

| BigQuery | Snowflake | |
|---|---|---|
| `` `project.dataset.table` `` | `database.schema.table` | unquoted identifiers are stored UPPERCASE (✓ `select 1 as mixedCase` returns `MIXEDCASE`) |
| `STRING`, `INT64`, `FLOAT64`, `NUMERIC`, `BOOL` | `VARCHAR`, `NUMBER`, `FLOAT`, `NUMBER(38,9)`, `BOOLEAN` | |
| `SAFE_CAST(x AS INT64)` | `TRY_CAST(x AS NUMBER)` | ✓ **only from text**: `try_cast(1.5::float as number)` is a compile error. Use `TRY_TO_NUMBER`, or cast the text |
| `SAFE_DIVIDE(a, b)` | `DIV0NULL(a, b)` (or `DIV0`) | ✓ plain `7/0` raises "Division by zero" |
| `IF(c, a, b)` | `IFF(c, a, b)` | ✓ |
| `COUNTIF(c)` | `COUNT_IF(c)` | ✓ |
| `DATE_TRUNC(d, MONTH)` | `DATE_TRUNC('month', d)` | ✓ argument order is swapped |
| `DATE_DIFF(end, start, DAY)` | `DATEDIFF('day', start, end)` | ✓ order swapped: `datediff('day', '2026-11-01', '2026-11-04')` = 3 |
| `DATE_ADD(d, INTERVAL 1 DAY)` | `DATEADD('day', 1, d)` | |
| `FORMAT_DATE('%Y-%m', d)` | `TO_CHAR(d, 'YYYY-MM')` | |
| `PARSE_TIMESTAMP(fmt, s)` | `TO_TIMESTAMP_NTZ(s, fmt)` | format codes differ (`YYYY-MM-DD HH24:MI:SS`) |
| `TIMESTAMP` (always UTC) | `TIMESTAMP_NTZ` by default | ✓ a new account's `TIMEZONE` is `America/Los_Angeles`: `'...09:30:00Z'::timestamp_ltz` shows 02:30 |
| `SELECT * EXCEPT (col)` | `SELECT * EXCLUDE (col)` | ✓ |
| `REGEXP_CONTAINS(s, r'x')` | `REGEXP_LIKE(s, '.*x.*')` or `REGEXP_INSTR(s, 'x') > 0` | ✓ `REGEXP_LIKE` must match the **whole** string: `regexp_like('hello world', 'world')` is FALSE |
| `ARRAY_AGG(x ORDER BY y DESC LIMIT 1)[OFFSET(0)]` | `MAX_BY(x, y)` | ✓ |
| `UNNEST(arr)` | `LATERAL FLATTEN(input => arr)` | `value` is a VARIANT: cast it (`value::varchar`) |
| `STRUCT` / `JSON` columns | `OBJECT` / `VARIANT` | `col:field::varchar` to read a field |
| `GENERATE_DATE_ARRAY(...)` | `dbt_utils.date_spine` or `TABLE(GENERATOR(ROWCOUNT => n))` | |
| `_PARTITIONTIME` filters | none | pruning comes from micro-partition metadata and `cluster_by` |
| `CREATE TEMP FUNCTION` (SQL/JS) | a UDF (`CREATE FUNCTION ... LANGUAGE SQL/PYTHON/JAVASCRIPT`) or a dbt macro | a macro is usually the dbt-native answer |
| `QUALIFY` | `QUALIFY` | same in both |

## 3. A porting order that works

1. Copy the Dataform repo into `legacy_dataform/` (read-only reference; see its README).
2. List every `declaration`: those are your **sources**. Load a sample of each into `RAW.<something>` in
   Snowflake (guide step 8) and write the `sources:` yml.
3. Port the first layer of models (the ones that only read declarations) into `models/legacy/staging/`.
   `dbt build -s legacy` after each one. Fix the dialect errors as they come; the table above covers most.
4. Port the next layer up, and so on. Assertions become tests as you go, not at the end.
5. Incremental models last: port them as `table` first, check the numbers, then switch to `incremental`.
6. Compare: row counts and a few key totals, old (BigQuery) vs new (Snowflake), per model.
