# Answers

Same numbering as the Exercises doc. The SQL drill numbers (section 3) were computed on your account's data on
4 Nov 2026, so yours should match exactly. Swap `dbt_elena` for your own `DBT_SCHEMA` if it differs.

## 1. Snowflake

**1.1** Not necessarily. Each size up doubles the compute (and the credits per hour), so a query that is big and
parallelisable (large scans, big joins, spilling to disk) speeds up roughly in proportion, at about the same total
cost. A small query that is bound by one step, or by waiting on a lock, doesn't. Scale **up** for heavy single queries,
or when the query profile shows "bytes spilled to local/remote storage". Scale **out** (multi-cluster, Enterprise
edition) for **concurrency**: many users or jobs queueing on one warehouse. Then extra clusters start automatically
and the queue disappears, but no single query gets faster.

**1.2** (1) **Result cache**: the exact same query text, the same role and unchanged underlying data, returns the
stored result for free (no warehouse needed). It lasts 24 h, each reuse extends it, up to 31 days. It is invalidated
when the data changes, or when the query uses non-deterministic functions such as `current_timestamp()`.
(2) **Warehouse (local disk) cache**: table data the warehouse already read sits on its SSDs. It is lost when the
warehouse **suspends**, which is why the next morning is slow again. (3) **Metadata**: `count(*)`, `min`/`max` on
a column and similar can be answered from micro-partition metadata with no warehouse at all.

**1.3** Per second, with a 60-second minimum **every time it resumes**. A dbt run is short bursts with gaps; with
`auto_suspend = 600` every burst pays for up to 10 idle minutes afterwards. 60 s throws away the local cache sooner,
which is cheap for this workload. (The trade-off flips for BI dashboards that query constantly.)

**1.4** Tables are stored as immutable micro-partitions of 50 to 500 MB (uncompressed), columnar, and Snowflake keeps
each column's min/max per partition. A filter on a column whose values are well grouped across partitions lets it
**prune** (skip) most of them. A clustering key reorders data in the background to keep that grouping; it costs
credits (automatic clustering), so it is worth it only on large tables (roughly multi-TB) that are filtered on the
same column constantly. Check with
`select system$clustering_information('analytics.dbt_elena_marts.fct_orders', '(order_date)');`: at 10,373 rows it
is a handful of partitions, so no.

**1.5**
```sql
create table analytics.dbt_elena_marts.fo_copy clone analytics.dbt_elena_marts.fct_orders;
delete from analytics.dbt_elena_marts.fo_copy where order_id < 1000101;              -- 100 rows
-- way 1: query the past and put the rows back
insert into analytics.dbt_elena_marts.fo_copy
  select * from analytics.dbt_elena_marts.fo_copy at(offset => -60*5) where order_id < 1000101;
-- way 2: clone the table as it was before the delete (use the DELETE's query id from Query History)
create table analytics.dbt_elena_marts.fo_restored clone analytics.dbt_elena_marts.fo_copy before(statement => '<query id>');
```
Time Travel is yours to query (`at`/`before`, `undrop`), 1 day by default and up to 90 days on Enterprise.
**Fail-safe** is a further 7 days that only Snowflake Support can restore from, for permanent tables only.
A `transient` table has at most 1 day of Time Travel and no Fail-safe, so it stores fewer old versions: good for
tables you can rebuild (most of a dbt project; dbt can make models transient).

**1.6** `COPY INTO` keeps **load metadata** per table: which file (name + ETag/checksum) was loaded and when, for
**64 days**. Files it knows are skipped. (Files older than 64 days with unknown status need
`load_uncertain_files = true`.) `force = true` loads them all again, so `raw.shop.orders` gets every row twice.
`stg_shop__orders` would hide that for orders (its `qualify` keeps one row per `order_id`), but
`stg_shop__order_lines` has no dedupe: the `unique` test on `order_line_id` fails, and if you ignored it, every
order's line totals in `fct_orders` would double. That is why the tests are there.

**1.7** A clone copies metadata only: both tables point at the same micro-partitions. Storage starts to cost when
either side changes data, because changed partitions are new and only one table points at them. In dbt: clone
production into a dev or CI database so you build against real data with no copy (`dbt clone` does it per model),
and blue/green deploys (build into a clone, then `swap with`).

**1.8** Best practice splits duties: SECURITYADMIN (and USERADMIN) manages users, roles and grants; SYSADMIN owns
databases, warehouses and objects; ACCOUNTADMIN is kept for billing and emergencies. Custom roles are granted **to**
SYSADMIN so the role hierarchy can see what they create. A **future grant** says "any table created in this database
from now on is automatically readable by TRANSFORMER". Without it, the loader creates a new table and TRANSFORMER can't
see it: dbt fails with "does not exist or not authorized" until someone grants it by hand.

**1.9** A service user can't have a password or MFA prompt, so it can't be phished or fall back to a weak sign-in, and
Snowflake is phasing out password-only sign-in for programs. Rotation:
```sql
alter user pipeline_svc set rsa_public_key_2 = '<new public key>';   -- both keys now work
-- switch .env / the Airflow connection to the new private key, check runs succeed
alter user pipeline_svc unset rsa_public_key;                         -- retire the old one
```
(Slot 2 currently holds Pippa's key, so use it or unset it first.)

**1.10**
```sql
select j:order.id::number as order_id, l.value:sku::varchar as sku, l.index as line_position
from raw_json_table,
     lateral flatten(input => j:order.lines) l;
```

**1.11** A **stream** records the changes (inserts, updates, deletes) to a table since you last read it. A **task**
runs SQL on a schedule or when a stream has data. A **dynamic table** is a declarative query that Snowflake keeps
refreshed to a target lag (`target_lag = '15 minutes'`), incrementally where it can. Use a dynamic table when you need
near-real-time freshness for a simple transformation and don't want an orchestrator in the loop. dbt is better when you
want tests, documentation, version control, and when many models depend on each other. (dbt can also build dynamic
tables: `materialized='dynamic_table'`.)

**1.12** It counts the credits its warehouses use in each period. At 75% `trial_guard` **notifies** (account admins
get an email); at 100% it **suspends**: the warehouses stop once the queries already running finish.
`suspend_immediate` cancels running queries too. Monitors only cover warehouse compute, not serverless features or
storage.

## 2. dbt

**2.1** (1) The **DAG**: dbt knows the order to build things in and what is downstream of a change (`-s model+`).
(2) **Environment-aware names**: the same code points at your dev schema in dev and at prod in prod.
(3) **Lineage and docs**, and selection by graph (`+model`, `state:modified+`). Bonus: `--defer` can resolve a `ref`
to production when you haven't built it in dev.

**2.2** `macros/generate_schema_name.sql`. In dev it prefixes everything with your own schema, so two developers
never overwrite each other's tables or production. In prod it uses the clean name.

**2.3** Staging = **views**: thin renames and casts, always current, cost nothing to "build". Marts = **tables**:
queried a lot, so computing them once is cheaper than on every read. `fct_orders` = **incremental**: it is the biggest
and only a few orders change each day. Snapshot = **history** that can't be recomputed later. **Ephemeral** is
inlined as a CTE into whatever references it: it is bad when several models use it (the logic runs once per user),
when you need to debug it (it doesn't exist in the warehouse), or when it is big.

**2.4** The second run's SQL (in `target/run/`) is a `merge into ... using (select ... where updated_at > (select
max(updated_at) from <this>))`. `is_incremental()` is true only if all four hold: the model is materialized
incremental, the table already exists in the warehouse, it is a table (not a view), and you didn't pass
`--full-refresh`.

**2.5** The change is **not** picked up: its `updated_at` is below the table's max, so the filter skips it. That is the
classic incremental bug when a source can deliver late or out of order. Fixes:
(a) a **lookback window**: `where updated_at > (select dateadd('day', -3, max(updated_at)) from {{ this }})`. Merge on
`order_id` makes reprocessing safe. It costs reprocessing 3 days every run, and anything later than 3 days is still
missed.
(b) filter on **when the row arrived**, not on the business timestamp: carry `_loaded_at` through staging and use
`where _loaded_at > (select max(_loaded_at) from {{ this }})`. That is exact for this loader, but needs the audit column
all the way through. Plus a periodic `--full-refresh` as a safety net either way.

**2.6** Snowflake's `MERGE` fails with "Duplicate row detected during DML action" when two source rows match the same
target row (the default `ERROR_ON_NONDETERMINISTIC_MERGE = true`). Here `stg_shop__orders` prevents it: its
`qualify row_number() ... = 1` keeps exactly one row per `order_id`, and the `unique` test on it proves that before
`fct_orders` runs.

**2.7** `ignore` (default): the new column isn't added; the model keeps working on the old columns.
`append_new_columns`: it is added, existing rows get NULL. `sync_all_columns`: added and removed columns are both
synced (and data type changes too). `fail`: the run stops. You need `--full-refresh` when old rows should **have
values** in the new column, or when the logic of existing columns changed.

**2.8** Each change closes the current row (`dbt_valid_to` = when it changed) and inserts a new one
(`dbt_valid_from` = then, `dbt_valid_to` = NULL, i.e. current). `check` compares the listed columns' values (no
reliable `updated_at` needed); `timestamp` trusts an `updated_at` column (cheaper, and it catches changes to any
column). A row deleted in the source stays "current" by default. Set `hard_deletes: invalidate` to close it, or
`new_record` to add a row that marks it as deleted.

**2.9** A **generic** test is a parameterised macro you attach to columns in yml (`unique`, `not_null`,
`accepted_values`, `relationships`, your own). A **singular** test is one `.sql` file that returns bad rows.
`severity: warn` reports the 120 rows without failing the build. `store_failures: true` saves the failing rows in a
table you can query. **Unit tests** (dbt 1.8+) run a model's logic on small, hand-written input rows and compare the
output to expected rows: they test the SQL, while data tests test the data.

**2.10** Because `NULL > 0` is NULL, not false. A test written as `where not (unit_price > 0)` or
`where unit_price <= 0` doesn't return NULL rows, so they pass silently. Whether it should catch them is a design
decision. Usually keep the two concerns separate: `not_null` for presence, `is_positive` for sign, each with its own
severity.

**2.11** `state:modified+` selects only models whose code or config changed against a saved production manifest, plus
everything downstream. `--defer` makes `ref()`s to models you didn't build resolve to production's tables. Together a
CI run builds 5 models instead of 400, against real upstream data.

**2.12** `run` builds models; `test` runs tests; `build` does models, tests, snapshots and seeds together in DAG
order, and runs each model's tests right after it. If a test fails, everything downstream is **skipped**, so bad data
doesn't flow on. (That is also what Cosmos's `AFTER_EACH` reproduces in Airflow.)

**2.13** `target/compiled` is your model's `select` with Jinja resolved. `target/run` is the statement dbt actually
executed, wrapped in its DDL/DML (`create or replace view`, `merge into`...). dbt parses every file **before** it can
run queries (to build the DAG). `execute` is false during that parse, so `{% if execute %}` stops `run_query()` from
running then, when there is no connection and its result would be meaningless.

## 3. SQL drills

**3.1** **98 people** have 2 customer IDs each: **196 IDs, 98 surplus**. Distinct emails: **2,494** raw vs **2,398**
after `lower(trim())`; normalising finds 96 more duplicates.
```sql
with c as (select customer_id, email, count(*) over (partition by email) n
           from analytics.dbt_elena_staging.stg_shop__customers)        -- email is already lower(trim())
select count(distinct email) people, count(*) ids, count(*) - count(distinct email) surplus from c where n > 1;
```
To fix it: keep the earliest-registered ID per email as the person (`min_by(customer_id, created_at)`), and map every
ID to it in an `int_customer_identity` model before `dim_customers`.

**3.2** **120 orders.** **78** are off by exactly £5 and **42** by exactly £10 (after allowing for the £3.95
shipping). Discount codes don't explain it: only 40 of the 120 have one, and discounts are already inside the line
amounts. Round amounts like that mean the header total is wrong at the source. Trust the **lines** (they are the item
level, and they reconcile everywhere else). Flag the order, and report the gap to whoever owns the source.
```sql
select count(*) n,
  count_if(abs(total_price - lines_net_amount) between 4.99 and 5.01 or abs(total_price - lines_net_amount - 3.95) between 4.99 and 5.01) off_5,
  count_if(abs(total_price - lines_net_amount) between 9.99 and 10.01 or abs(total_price - lines_net_amount - 3.95) between 9.99 and 10.01) off_10,
  count_if(discount_code is not null) with_code
from analytics.dbt_elena_marts.fct_orders
where lines_missing_price = 0
  and abs(total_price - lines_net_amount) > 0.01
  and abs(total_price - (lines_net_amount + 3.95)) > 0.01;
```

**3.3** Aug 2026 **£21,343.47** (-3.4%), Sep **£20,971.07** (-1.7%), Oct **£22,770.35** (+8.6%). Rolling 12 months
at Oct: **£226,694.68**.
```sql
with m as (select date_trunc('month', order_date) mth, sum(total_price) rev
           from analytics.dbt_elena_marts.fct_orders where is_revenue group by 1)
select mth, rev,
       round(100 * (rev / lag(rev) over (order by mth) - 1), 1) mom_pct,
       sum(rev) over (order by mth rows between 11 preceding and current row) r12
from m order by mth;
```
The trap: `rows between` counts **rows**, not months. A month with no orders has no row, so "11 preceding" quietly
reaches back 13 months. Guard with a month spine left-joined in (`dbt_utils.date_spine` or `generator`), so every
month has a row, even a zero.

**3.4** **646** order IDs appear more than once; **480** of them changed `financial_status`; **164** are now cancelled
(voided). There are 11,019 raw rows for 10,373 orders. Naive revenue on RAW **£466,019.02** vs correct
**£436,811.11**: overstated by **£29,207.91** (6.7%), mostly from counting a refunded or voided order's earlier
"paid" version.
```sql
with v as (select id, count(*) versions, count(distinct financial_status) statuses,
                  max(iff(cancelled_at is not null, 1, 0)) cancelled
           from raw.shop.orders group by 1)
select count_if(versions > 1), count_if(versions > 1 and statuses > 1), count_if(versions > 1 and cancelled = 1) from v;
```

**3.5** **51** customers in the January 2025 cohort; **23** ordered again within 90 days: **45.1%**.
```sql
with f as (select customer_id, min(order_date) first_dt
           from analytics.dbt_elena_marts.fct_orders where is_revenue group by 1),
nxt as (select f.customer_id, f.first_dt, min(o.order_date) second_dt
        from f left join analytics.dbt_elena_marts.fct_orders o
          on o.customer_id = f.customer_id and o.is_revenue and o.order_date > f.first_dt
        group by 1, 2)
select count(*), count_if(datediff('day', first_dt, second_dt) <= 90),
       round(100 * count_if(datediff('day', first_dt, second_dt) <= 90) / count(*), 1)
from nxt where date_trunc('month', first_dt) = '2025-01-01';
```
Trap: `left join` keeps one-time buyers (their `second_dt` is NULL, which `count_if` treats as not back). An inner
join would drop them and inflate the rate.

**3.6** **225** customers; the longest streak is **25** consecutive months.
```sql
with m as (select distinct customer_id, date_trunc('month', order_date) mth
           from analytics.dbt_elena_marts.fct_orders where is_revenue),
g as (select customer_id, mth,
             dateadd('month', -row_number() over (partition by customer_id order by mth), mth) grp
      from m),
s as (select customer_id, grp, count(*) len from g group by 1, 2)
select count(distinct customer_id), max(len) from s where len >= 6;
```
The trick: subtract the row number (in months) from the month. Consecutive months collapse to the same value, so
each streak becomes one group.

**3.7** **567** at 31 Oct, **534** at 30 Sep, **509** at 31 Aug 2026.
```sql
with spine as (select last_day(dateadd('month', seq4(), '2025-01-01'::date)) month_end
               from table(generator(rowcount => 22)))
select month_end, count(s.subscription_id) active
from spine left join analytics.dbt_elena_staging.stg_shop__subscriptions s
  on s.created_at::date <= month_end and (s.cancelled_at is null or s.cancelled_at::date > month_end)
group by 1 order by 1 desc;
```
`count_if(status = 'active')` gives **499**: `status` is the subscription's state **today**, so it can't answer "how
many at the end of August", and the 68 currently **paused** subscriptions aren't cancelled (567 = 499 + 68). Which is
right depends on whether paused counts as active: decide it, write it down, test it. True history of pauses needs
the snapshot (2.8).

**3.8** Oct 2026: spend **£18,940.92**, **63** new customers, CAC **£300.65**, MER **1.20**.
Nov 2025: spend **£23,386.11**, **52** new, CAC **£449.73**, MER **0.65** (Black Friday spend more than doubles).
```sql
with first_orders as (select customer_id, date_trunc('month', min(order_date)) mth
                      from analytics.dbt_elena_marts.fct_orders where is_revenue group by 1),
nc as (select mth, count(*) new_customers from first_orders group by 1),
sp as (select date_trunc('month', spend_date) mth, sum(spend) spend
       from analytics.dbt_elena_staging.stg_shop__ad_spend group by 1),
rev as (select date_trunc('month', order_date) mth, sum(total_price) revenue
        from analytics.dbt_elena_marts.fct_orders where is_revenue group by 1)
select sp.mth, spend, new_customers, round(div0null(spend, new_customers), 2) cac, round(div0null(revenue, spend), 2) mer
from sp left join nc using (mth) left join rev using (mth) order by 1;
```
The biggest definition choice: what counts as a **new customer**. First **revenue** order (used here), first order of
any status, or registration date give very different denominators; the duplicate people from 3.1 inflate it too.
Use `div0null`, because a month with spend and no new customers would otherwise error (`7/0` raises in Snowflake).

**3.9** **Joint Support Chews 120** wins everywhere (GB £65,781.13) except **NL**, where it is the **Gift Box**
(£3,533.39).
```sql
with r as (select c.country_code, p.product_name, sum(l.quantity * l.unit_price - l.line_discount) rev
           from analytics.dbt_elena_staging.stg_shop__order_lines l
           join analytics.dbt_elena_marts.fct_orders o using (order_id)
           join analytics.dbt_elena_staging.stg_shop__customers c on c.customer_id = o.customer_id
           join analytics.dbt_elena_staging.stg_shop__products p using (product_id)
           where o.is_revenue group by 1, 2)
select * from r qualify rank() over (partition by country_code order by rev desc) = 1 order by 1;
```
`rank()` keeps ties; `row_number()` would silently pick one.

**3.10** **56 lines in 56 orders.** `sum(quantity * unit_price)` **skips** them silently: 14,030 lines, but only
13,974 have a price, and no error tells you. Options: fill from the product's `list_price` (`coalesce(l.unit_price,
p.list_price)`) and flag the line as imputed; or exclude the order from revenue and raise it. Don't leave it to
whoever reads the dashboard. `fct_orders.lines_missing_price` already counts them, so a test can watch it.

**3.11** Median **32 days**, mean **54.6 days**, over **1,009** customers. The mean is pulled up by a long tail
(customers who come back after many months). Subscribers' 30-day rhythm sets the median. Report the median, or
both. Order by `created_at`, not `order_date`: two orders on one day would otherwise come out in random order.
```sql
with o as (select customer_id,
                  datediff('day', lag(order_date) over (partition by customer_id order by created_at), order_date) gap,
                  count(*) over (partition by customer_id) n
           from analytics.dbt_elena_marts.fct_orders where is_revenue)
select median(gap), round(avg(gap), 1), count(distinct customer_id) from o where n >= 3 and gap is not null;
```

**3.12** **138** of the 5,060 orders placed in 2026. They are exactly the orders placed between 23:00 and 23:59 UTC
while the UK is on summer time (29 Mar to 25 Oct 2026): 23:30 UTC is 00:30 the next day in London.
```sql
select count(*), count_if(order_date <> convert_timezone('UTC', 'Europe/London', created_at)::date)
from analytics.dbt_elena_marts.fct_orders where created_at >= '2026-01-01';
```
Use the 3-argument `convert_timezone` (source zone stated) on an NTZ column. The session's `TIMEZONE` defaults to
America/Los_Angeles on a new account, which silently shifts anything that relies on it.

**3.13** Both should return **10,373** rows:
```sql
-- (a) a subquery on row_number()
select * from (
  select o.*, row_number() over (partition by id order by updated_at desc, _loaded_at desc, _file_name desc) rn
  from raw.shop.orders o) where rn = 1;
-- (b) join back to the latest version per id
select o.* from raw.shop.orders o
join (select id, max(updated_at) mx from raw.shop.orders group by 1) l on l.id = o.id and l.mx = o.updated_at;
```
(b) has a trap: two versions with the **same** `updated_at` both survive. Check `count(*)` vs
`count(distinct id)`; `qualify` with tie-breakers is the safe pattern.

## 4. Airflow

**4.1** **api-server** (the UI, the REST API, and the execution API that running tasks talk to; in Airflow 3 tasks
no longer touch the metadata database directly). **scheduler** (decides what runs when, hands tasks to the executor).
**dag-processor** (parses DAG files; its own process since Airflow 3). **triggerer** (runs deferred tasks' async
waits). Each file is re-parsed about every 30 s (`[dag_processor] min_file_process_interval`), and new files are
picked up on a slower scan.

**4.2** Anything slow at the top level (an API call, a database query, a heavy import) runs on every parse, roughly
twice a minute, forever. Cosmos must know the dbt graph at parse time. By default (`AUTOMATIC` → `DBT_LS`) it runs
`dbt ls`, a subprocess, and caches the result. `LoadMode.DBT_MANIFEST` reads a `manifest.json` produced at deploy time
(`dbt parse`) instead: parsing is then cheap and doesn't need dbt installed where the DAG is parsed.

**4.3** On switching it on, the scheduler at once creates the latest run it "missed": `scheduled__2026-11-04T06:00`.
Your manual run is created too but **waits**, because `max_active_runs=1`. (This happened in testing: the scheduled run
went 09:04:55 to 09:09:17, the manual one started at 09:09:18.) In Airflow 3 a cron schedule is a
`CronTriggerTimetable` by default: the run's **logical date is the trigger time itself**, 4 Nov 06:00, and its data
interval is a point (start = end = 06:00). In Airflow 2 the default was a data-interval timetable: the run that
executed at 06:00 on 4 Nov had logical date 3 Nov 06:00 and covered 3 Nov 06:00 to 4 Nov 06:00, the classic "why
is my logical date yesterday" confusion. With `catchup=True` you get a run for every 06:00 since `start_date`:
1, 2, 3 and 4 Nov, one at a time.

**4.4** Idempotent = running it twice for the same logical date leaves the same end state as running it once.
`load_raw` is (COPY INTO's load metadata skips loaded files). The dbt part is (views and tables are rebuilt;
incremental merges on a key). It would stop being idempotent with `force = true` on COPY, an incremental model with
`append` and no key, anything using `current_date` instead of the run's logical date for "which day to process", or a
task that sends emails or calls an external API.

**4.5** Clearing `dbt.fct_orders.run` (with "downstream" ticked) re-runs it, its test, `dim_customers` (run + test)
and `dbt_snapshot`. The six staging models and their tests are not re-run. With one big `dbt build` task you would
redo everything, or end up running dbt by hand outside Airflow.

**4.6** Local: tasks run as processes on the scheduler's machine; simple, fine for one machine. Celery: a pool of
always-on workers fed through a queue (Redis/RabbitMQ); good for many short tasks. Kubernetes: one pod per task, so
each task can have its own image, resources and isolation, at the cost of pod start-up time. The choice depends on
volume, isolation needs, and what the platform team already runs.

**4.7** A Connection lives in Airflow's metadata database (encrypted with the Fernet key) or in a secrets backend
(AWS Secrets Manager, Vault, GCP Secret Manager). It isn't in the shell of whoever started the scheduler, it can be
rotated without a restart, and permissions apply to it. Environment variables leak into every task's process and
into logs if someone prints them.

**4.8** In `poke` mode a sensor holds a worker slot for the whole wait (6 hours of a slot doing nothing). `reschedule`
mode frees the slot between checks. A **deferrable** operator hands the wait to the **triggerer**, which runs
thousands of waits as async coroutines in one process, and the task resumes on a worker only when the condition is
met.

**4.9** Small pieces of metadata passed between tasks (an ID, a file path, a row count). By default they are stored
in the metadata database, which isn't built for large payloads. Pass a **reference** (a table name, an S3 path)
instead of the data itself.

## 5. Porting

No fixed answers. Pippa will check them against your code once the old repository is in `legacy_dataform/source/`.

## 6. Shopify + Meta Ads

All numbers computed on your account on 4 Nov 2026, from the seeded data (a reload gives the same numbers).

**6.1** Leave out: test orders (`test`, 17), rows the connector marks deleted (`_fivetran_deleted`, 8), cancelled
orders, unpaid `pending` and `voided` orders, gift-card lines (£7,850 sold: a liability until someone redeems the card,
not revenue), refunded amounts, VAT (equipment lines are `taxable` at 20%, beans are zero-rated) and shipping.

```sql
with o as (select id, date_trunc(month, convert_timezone('Europe/London', created_at))::date as month
           from raw.shopify."ORDER"
           where not test and not _fivetran_deleted and cancelled_at is null
             and financial_status not in ('pending', 'voided')),
l as (select id, order_id, price * quantity - total_discount as net, iff(taxable, 1.2, 1) as vat_factor
      from raw.shopify.order_line where not gift_card),
r as (select order_line_id, sum(subtotal) as refunded from raw.shopify.order_line_refund group by 1)
select month, round(sum((l.net - coalesce(r.refunded, 0)) / l.vat_factor), 2) as net_sales_ex_vat
from o join l on l.order_id = o.id left join r on r.order_line_id = l.id
group by rollup (month) order by month nulls last;
```

Total **£248,311.96** (Dec 2025 the peak at £26,972.50; Nov 2026 is just £72.40 of early-morning orders before the last
sync). The naive `select sum(total_price) from raw.shopify."ORDER"` gives £292,480.45: **£44,168.49 (15%) too high**.
Two details: `price` on the order line is the price paid then (beans went up in March 2026; `PRODUCT_VARIANT.price`
only has today's price, so never join it in for revenue), and a refund here is counted against the order's month.
Counting it in the refund's month is the other valid choice: say which you used.

**6.2** 28 Nov 2025: **54** in UK time, **54** in UTC, **51** in Meta's account time (America/Los_Angeles).
15 Jun 2026: **24** UK, **23** UTC, **23** LA. In November the UK is on GMT, which is UTC; in June it is BST (UTC+1),
so midnight-to-1am orders move day. Meta's `date` is the **account's** day (a Los Angeles day, 08:00 to 08:00 UK
time in winter), so compare its spend with orders bucketed the same way: £280.99 / 51 = £5.51 blended cost per order.
Using UK days silently shifts 8 hours of orders. In a mart, pick one time zone and convert the other side to it.

**6.3** Current versions: `qualify row_number() over (partition by id order by updated_time desc) = 1`. The renamed
campaign: "Prospecting | Broad | Sales" became "PROS | Broad | Advantage+" on 2 Mar 2026. The `utm_campaign` values
that match no current name:

| utm_source | utm_campaign (after decoding %20 and %7C) | orders | why |
|---|---|---|---|
| facebook | PROS \| Broad \| Advantage%2B | 318 | `+` is URL-encoded too (`%2B`); a partial decode misses it. `PARSE_URL` returns the parameters still encoded (checked) |
| facebook | Prospecting \| Broad \| Sales | 179 | the old name: the UTM holds the name at the time of the click |
| fb | bf2025 | 64 | one Black Friday ad had its UTMs typed by hand, not from the template |

The key that survives renames and encoding is **`utm_content` = the ad id** → `AD_HISTORY.campaign_id`. Names are for
display; ids are for joins. The hand-typed ad has no `utm_content`, so it needs a small mapping (a dbt seed:
`bf2025` → the Black Friday campaign id).

**6.4** Valid orders (as in 6.1) by `utm_content` → ad → campaign (`total_price` = what the customer paid):

| Campaign | Orders | Revenue |
|---|---|---|
| PROS \| Broad \| Advantage+ | 489 | £17,644.51 |
| Retargeting \| 30d visitors | 324 | £10,617.14 |
| Christmas Gifting 2025 | 109 | £3,741.30 |
| Prospecting \| Lookalike 1% | 82 | £2,916.74 |
| Black Friday 2025 | 66 | £2,146.73 |
| Grinder Launch | 64 | £10,886.14 |
| Traffic \| Brew Guides | 4 | £204.74 |
| Brand Awareness \| Video | 1 | £31.95 |

Not attributable to a campaign by ad id: **291** orders with an `fbclid` but no UTMs (one retargeting ad's creative
has `url_tags` empty, see `CREATIVE_HISTORY`), and **63** with the hand-typed `utm_source=fb` (fixable with the seed).
Also invisible: people who clicked an ad and came back days later by typing the address; their order has no trace
of the ad at all.

**6.5** Meta reports **2,362** purchases: 1,697 within 7 days of a click plus 665 within 1 day of only *seeing* an
ad. By campaign: Retargeting 954, PROS 769, Black Friday 192, Christmas 178, Lookalike 131, Grinder 122, Awareness 9,
Traffic 7. Summing every `action_type` like `'%purchase%'` gives **7,086 = 3 × 2,362**: `purchase`,
`offsite_conversion.fb_pixel_purchase` and `omni_purchase` are the same purchases reported three ways. Pick one
(`purchase`) and say so in the model.

**6.6** Spend from `BASIC_AD`, Meta's value from `BASIC_AD_ACTION_VALUES` (`purchase` only), Shopify revenue from 6.4:

| Campaign | Spend | ROAS, Meta | ROAS, Shopify last click |
|---|---|---|---|
| PROS \| Broad \| Advantage+ | £21,582.58 | 1.23 | 0.82 |
| Retargeting \| 30d visitors | £9,011.12 | 3.66 | 1.18 |
| Grinder Launch | £4,526.51 | 3.09 | 2.40 |
| Prospecting \| Lookalike 1% | £3,698.11 | 1.24 | 0.79 |
| Brand Awareness \| Video | £2,862.80 | 0.10 | 0.01 |
| Christmas Gifting 2025 | £2,399.06 | 2.58 | 1.56 |
| Traffic \| Brew Guides | £2,322.53 | 0.10 | 0.09 |
| Black Friday 2025 | £2,219.48 | 3.10 | 0.97 (too low: 63 of its orders hide behind `bf2025`) |

Retargeting looks best on Meta's numbers and keeps about a third of it: Meta counts view-through purchases and
people who were going to buy anyway (they visited the site in the last 30 days), and gives credit by the click date
across a 7-day window. Last click under-credits the other way: anyone who came back later directly. Neither is the
truth. Tell the manager both, call Meta's number "platform-reported", and suggest a holdout test for the real
answer. The Grinder Launch is the one campaign that pays clearly on both.

**6.7** Summing daily reach for October gives 38,973 (94,939 impressions, so a "frequency" of 2.44), but that counts
a person once for **every day** they saw an ad: it is person-days, not people. Unique reach is not additive, so no
sum of daily rows can give it; the real October reach (lower) has to come from Meta itself for that date range
(an insights pull at monthly level). Same for frequency. In dbt, never put `reach` in an additive measure.

**6.8** `daily_budget` is in **minor units** (pence): 5000 = £50. Budget versions come from `CAMPAIGN_HISTORY`; convert
`updated_time` to the account's time zone to get the day each budget applies from, then:

```sql
with c as (select daily_budget / 100 as budget,
                  convert_timezone('America/Los_Angeles', updated_time)::date as from_day
           from raw.meta_ads.campaign_history
           where name like '%Lookalike%' and status = 'ACTIVE'),
s as (select b.date, sum(b.spend) as spend
      from raw.meta_ads.basic_ad b
      join (select distinct id, campaign_id from raw.meta_ads.ad_history) a on a.id = b.ad_id
      where a.campaign_id = 120200000007000782
      group by 1)
select count(*) as days, count_if(s.spend > c.budget) as days_over, round(max(s.spend / c.budget), 3) as worst
from s asof join c match_condition (s.date >= c.from_day);
```

45 days, **14 over budget** (6 at £50, 5 at £80, 3 at £120), the worst 4.7% over; £3,698.11 spent against £3,780 of
budget. Meta lets a single day go over its daily budget as long as the week evens out, so "over budget on a day" is
normal; over across the week is the real alert. `ASOF JOIN` is Snowflake's join for "the version in force at that
time"; the long way is a range join on `from_day` / next version's `from_day` (built with `lead()`).

**6.9** **73** emails have more than one customer account (the same person signed up again with a capital letter in
the email), and 249 orders are guest checkouts with no `customer_id` at all. Shopify's `orders_count` is per
account, so a returning customer on a second account counts as new, and guests aren't counted anywhere. Build
"first order" yourself, on `lower(trim(email))` across all orders.

**6.10** Sale transactions match `total_price` for every GBP order, and for **none** of the 551 EUR and 60 USD orders:
`TRANSACTION.amount` is in the **presentment** currency (what the customer paid, in euros or dollars), while
`total_price` is in the shop's currency. `total_price_set` holds both: `shop_money` (GBP) and `presentment_money`
(what was charged), which matches the transactions exactly (checked: 0 of 8,175 differ). Also filter to `status = 'success'`: there are declined attempts too. Refunds
(GBP orders): 419, of which **26 differ, by £102.70 in total = 26 × £3.95**: shipping refunded on cancelled orders,
which goes back on the transaction but has no refund line. So refunded revenue is not the same as refunded cash.

**6.11** No fixed answer: Pippa reviews the code.
