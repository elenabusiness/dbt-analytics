# Exercises: Snowflake, dbt, Airflow, and SQL on the pipeline

Answers are in the separate **Answers** doc, same numbering. Try each one first. Tables are in your dev schemas
(`ANALYTICS.DBT_ELENA_STAGING`, `..._MARTS`): replace `dbt_elena` with your own `DBT_SCHEMA` if you chose another.
Tasks marked 🛠 are hands-on; the rest are "explain it as you would in an interview".

## 1. Snowflake

1.1 A query takes 40 s on X-Small. You resize to Large (8x the compute). Will it take 5 s? When does scaling **up**
help, and when do you want a **multi-cluster** warehouse (scaling **out**) instead?

1.2 The same `select` runs in 4 s the first time and 50 ms the second, then 3 s the next morning even though the
data didn't change. Name the three caches involved and what invalidates each.

1.3 🛠 Run `alter warehouse transform_wh suspend;` then a small query, twice in quick succession. Look at
**Monitoring → Query History**. How is a warehouse billed (minimum per resume, then per what?), and why does
`auto_suspend = 60` usually beat `auto_suspend = 600` for a dbt project?

1.4 What is a micro-partition, and how does Snowflake skip data without indexes or user-defined partitions? When is
a clustering key worth its cost, and how would you check whether `fct_orders` needs one?
(Hint: `system$clustering_information`.)

1.5 🛠 Time Travel. Delete 100 rows from a **copy** of `fct_orders` (`create table x clone ...`), then get them back
two different ways. What is the difference between Time Travel and Fail-safe, and why does a `transient` table cost
less?

1.6 🛠 `scripts/load_raw.py` runs `COPY INTO` on files that are already loaded and loads 0 rows. How does Snowflake
know? How long does it remember? What would `force = true` do to `raw.shop.orders`, and what would dbt's
`stg_shop__orders` then do about it?

1.7 `create table b clone a` on a 2 TB table finishes in a second and costs no storage. Why? When does it start
costing storage? Give two uses of cloning in a dbt workflow.

1.8 Roles. Why does `00_setup.sql` create objects as SYSADMIN but roles as SECURITYADMIN? What exactly do the
`future` grants in it do, and what breaks for `TRANSFORMER` if you remove them and the loader adds a new table?

1.9 🛠 Why is `PIPELINE_SVC` `type = service` with a key pair, not a password? Rotate its key without downtime
using both key slots.

1.10 Snowflake has `VARIANT`. A source sends JSON like `{"order": {"id": 1, "lines": [{"sku": "A"}, ...]}}`.
Write the SQL to get one row per line with the order id and sku. (Keyword: `lateral flatten`.)

1.11 Streams, tasks and dynamic tables: what each is, and when you would use a dynamic table instead of a dbt
incremental model.

1.12 What is a resource monitor, and what does `trial_guard` do at 75% and at 100%? Why does it not stop queries
already running unless you choose `suspend_immediate`?

## 2. dbt

2.1 What does `ref()` give you that typing `analytics.dbt_elena_staging.stg_shop__orders` does not? Name three things.

2.2 Your models land in `DBT_ELENA_STAGING` in dev but `STAGING` in prod. Which file decides that, and why do
teams not just use `STAGING` in dev too?

2.3 Materializations: view, table, incremental, ephemeral, snapshot. For each layer of this project, why was the one
it uses chosen? When is an ephemeral model a bad idea?

2.4 🛠 `fct_orders` is incremental. Run `dbt build -s fct_orders` twice and compare the SQL dbt sent the second time
(`target/run/...`). What exactly does `is_incremental()` check before it returns true?

2.5 🛠 **The late-arriving update bug.** `fct_orders` only picks up orders with `updated_at > max(updated_at)` in the
table. Insert a row into `raw.shop.orders` for an existing order with a newer status but an `updated_at` **older** than
that max, run `dbt build -s +fct_orders`. Is the change in `fct_orders`? Fix the model so it is (two different
ways), and say what each fix costs.

2.6 `unique_key`, `merge` and duplicates: what happens to an incremental merge if the new batch contains the same
`order_id` twice? Where in this project is that prevented?

2.7 `on_schema_change`: a new column appears in the source. What do `ignore`, `append_new_columns`,
`sync_all_columns` and `fail` each do to `fct_orders`? When do you need `--full-refresh` anyway?

2.8 🛠 The snapshot. Change one subscription's status in RAW (as LOADER), run `dbt snapshot`, and query
`dbt_elena_snapshots.subscriptions_snapshot` for it. Explain `dbt_valid_from`, `dbt_valid_to`, `check` vs
`timestamp` strategy, and what happens to a row that is deleted from the source.

2.9 Tests. The difference between a generic test and a singular test; what `severity: warn` did for
`assert_order_total_matches_lines`; how `store_failures` would help you debug it; and what dbt **unit tests** check
that data tests can't.

2.10 🛠 Write a generic test `is_positive(column)` in `tests/generic/` and apply it to `fct_orders.total_price` and
to `stg_shop__order_lines.unit_price`. Both pass, yet 3.10 shows `unit_price` has NULLs. Why did your test not catch
them, and should it?

2.11 Slim CI: what do `state:modified+` and `--defer` do, and why do they matter on a 400-model project?

2.12 What is the difference between `dbt run`, `dbt build` and `dbt test`, and in what order does `build` run a model
and its tests?

2.13 Jinja: what is the difference between what you see in `target/compiled` and `target/run`? Why does
`{% if execute %}` appear around `run_query()` in macros?

## 3. SQL drills on the pipeline (all answers checked on your data)

3.1 How many people (by email, after trimming and lower-casing) have **more than one** `customer_id`? How many surplus
customer IDs is that? Then: how many distinct emails are there before normalising vs after?

3.2 `assert_order_total_matches_lines` warns on some orders. How many? Categorise them by the size of the difference.
Are discount codes the explanation? Which number would you trust for revenue, the header or the lines, and why?

3.3 Monthly revenue (`is_revenue` orders) for Aug, Sep, Oct 2026, with month-on-month % change and a rolling
12-month total. What silently breaks a `rows between 11 preceding and current row` window, and how do you guard
against it?

3.4 In `raw.shop.orders`: how many order IDs appear more than once? How many of those changed `financial_status`
between versions? How many are now cancelled? Then compute "revenue" naively from RAW and correctly from
`fct_orders`: what is the difference in £?

3.5 Retention: of customers whose **first revenue order** was in January 2025, how many ordered again within 90 days?
As a %?

3.6 Gaps and islands: how many customers have ordered in **at least 6 consecutive calendar months**? What is the
longest streak?

3.7 Active subscriptions at the end of each month (build a month-end date spine). How many at 31 Oct, 30 Sep, 31 Aug
2026? Why is `count_if(status = 'active')` a different number, and which question does each answer?

3.8 Blended CAC and MER per month: ad spend ÷ new customers (first revenue order that month), and revenue ÷ spend.
Give Oct 2026 and Nov 2025. What definition choice changes CAC the most?

3.9 Best-selling product by revenue in each country, keeping ties. Which country is the odd one out?

3.10 Some order lines have a NULL price. How many lines and orders? What does `sum(quantity * unit_price)` do with
them, and how would you handle them in `fct_orders`?

3.11 For customers with at least 3 revenue orders: the median and the mean number of days between consecutive orders.
Why are they so different, and which would you report?

3.12 Timestamps are stored in UTC. How many 2026 orders fall on a **different calendar date** in UK time? Why exactly
that set of orders?

3.13 Rewrite `stg_shop__orders` without `qualify` (two ways), and prove you get the same 10,373 rows.

## 4. Airflow

4.1 Airflow 3 runs as several processes (`airflow standalone` started them all). Name them and what each does.
Which one parses your DAG file, and how often?

4.2 What runs at the top level of a DAG file runs on **every parse**. Why does that matter, and what does Cosmos do at
parse time for `shop_pipeline`? How would you make that cheaper (look up Cosmos `LoadMode.DBT_MANIFEST`)?

4.3 `schedule="0 6 * * *"`, `start_date=2026-11-01`, `catchup=False`. You switch it on at 09:00 on 4 Nov and press
Trigger straight away. Which runs happen, in what order, and why does your manual run sit queued? What are the
scheduled run's logical date and data interval in Airflow 3, and how is that different from Airflow 2? What changes
with `catchup=True`?

4.4 What makes a task **idempotent**, and is `load_raw` idempotent? Is the dbt part? What would make either of them
not idempotent?

4.5 🛠 Make `dbt.fct_orders.run` fail (break its SQL), trigger the DAG, then fix it and **clear** just that task so the
run finishes. Which downstream tasks re-run, and why is that the reason for Cosmos's one-task-per-model design?

4.6 Executors: Local vs Celery vs Kubernetes. What decides the choice in production?

4.7 🛠 Move the Snowflake settings out of `.env` into an **Airflow Connection** (`snowflake_default`), and switch the
DAG to Cosmos's `SnowflakePrivateKeyFilePemProfileMapping` (your key has no passphrase; the `Encrypted...` one is
for a key that has one). Why is a Connection
better than environment variables in a shared deployment?

4.8 Sensors and deferrable operators: what is the problem with a sensor that waits 6 hours in `poke` mode, and what
does the triggerer solve?

4.9 XComs: what are they for, and why should you not pass a DataFrame through one?

## 5. Porting the old pipeline

5.1 List every Dataform `declaration` in the old repo and write `sources:` for them, with `freshness` on the ones that
should arrive daily.

5.2 Find every `incremental` model in the old repo. For each: its unique key, its incremental condition, and
whether that condition has the late-arriving bug from 2.5.

5.3 Find every `${when(incremental(), ...)}`, `${self()}` and `includes/` function, and decide what each becomes
in dbt (macro, var, or plain Jinja).

5.4 Port one assertion to a dbt test and prove it fails on purpose with bad data.

5.5 Pick the model with the most BigQuery-specific SQL (arrays, `SAFE_` functions, date functions) and port it.
Keep a list of every dialect change you made: that list is a great interview answer.

5.6 Reconciliation: for each ported model, compare row counts and two key totals between BigQuery and Snowflake.
Explain every difference you find.

5.7 Once it builds: put it in the Airflow DAG as a second `DbtTaskGroup` selected with `RenderConfig(select=["path:models/legacy"])`.

More drills on the real pipeline will follow once its code is in `legacy_dataform/source/`.

## 6. Shopify + Meta Ads (marketing data)

The data is in `RAW.SHOPIFY` and `RAW.META_ADS` (see the **Shopify + Meta Ads data** doc). Every answer was checked on
your account. These are the questions an e-commerce data team gets asked every week, with the traps the real
connectors set.

6.1 🛠 **Revenue finance would sign off.** Net product sales, **ex VAT**, by month in **UK time**. Decide and say
what you leave out (there are at least six kinds of row or money that are not revenue here), then compare your
year's total with a naive `sum(total_price)` over the whole order table. How big is the gap?

6.2 🛠 **Which day is "Black Friday"?** How many (non-test) orders were placed on 28 Nov 2025 in shop time, in UTC,
and in the Meta account's time zone? Then the same for 15 Jun 2026. Why do two of the three agree in November but
not in June? Meta says it spent £280.99 "on 28 Nov": which order count do you divide that by for cost per order?

6.3 🛠 **Campaign names.** List every campaign's **current** name, status and daily budget in pounds. Which campaign
was renamed? Now pull `utm_campaign` out of Shopify's `landing_site` and find the values that match no current
campaign name. Explain each one, then find the join key that survives all of it.

6.4 🛠 **Last-click attribution.** Orders and revenue per campaign, using the UTMs on Shopify orders (valid orders
only, as in 6.1). How many Meta-driven orders can't be attributed to a campaign at all, and why?

6.5 🛠 **Meta's version.** Purchases per campaign as Meta reports them. Split them into 7-day-click and 1-day-view.
Then sum `value` for every `action_type` containing "purchase": what do you get, and why is it wrong?

6.6 🛠 **ROAS two ways.** Return on ad spend per campaign: Meta's purchase value / spend, and Shopify last-click
revenue / spend. Which campaign looks best on Meta's numbers, and how much of that survives? What would you tell
the marketing manager?

6.7 **Reach.** Sum `reach` for the retargeting campaign over October 2026. What does that number mean, and what
does it not? How would you get the real October reach?

6.8 🛠 **Budget pacing (as-of join).** The lookalike campaign's budget changed twice. For each day it ran, find the
budget in force **that day** and compare it with the day's spend. How many days went over budget? (Snowflake has a
join made for exactly this.) Watch the units of `daily_budget`.

6.9 🛠 **Customers.** How many emails belong to more than one customer account? Shopify's `orders_count` is per
account: what happens to a "new vs returning customer" report if you trust it?

6.10 🛠 **Payments reconciliation.** For each order, compare successful `sale` transactions with `total_price`. Which
orders never match, and why? Then compare each refund's transaction with the sum of its refund lines (GBP orders):
how many differ, by how much in total, and what is the money that has no line?

6.11 🛠 **dbt.** Build staging models for both sources (current-version models for the `*_HISTORY` tables, `"ORDER"`
renamed), `fct_orders_attributed` and `fct_ad_performance`, with tests that would have caught 6.3, 6.5 and 6.10.
Pippa will review the code.
