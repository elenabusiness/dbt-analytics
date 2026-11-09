# Reading list

Topics you want to read about. When you send a new one to Pippa it goes at the bottom, with the date.
Each topic has a few official pages to start with, then questions to check you understood it. Most
questions point back at something in your own lab, so you can look at the real thing while you read.

---

## 1. Running dbt locally vs in the cloud: practicalities and cost

*Added 6 Nov 2026.*

**The idea to hold on to:** dbt itself does very little work. It turns your models into SQL and sends
that SQL to Snowflake. The heavy lifting runs on a Snowflake warehouse wherever dbt is started from,
so the Snowflake bill depends on the warehouse and how long it runs, not on where dbt lives. "Local vs
cloud" is really about *who runs the dbt command, on which machine, and when*.

The three usual set-ups:
- **dbt Core on your laptop** (what you have now): free and open source. You run it by hand, it stops
  when the Mac sleeps, and it signs in with credentials on your machine.
- **dbt Core on a server or scheduler**: the same free dbt, started by Airflow (your DAG does this via
  Cosmos), a container or a CI job. You pay for the machine it runs on, and someone has to look after it.
- **dbt Cloud** (dbt Labs now calls it "the dbt platform"): a paid hosted service with an IDE in the
  browser, a scheduler, CI on pull requests and hosted docs. It pulls your code from git onto its servers.

**Read:**
- [Install dbt](https://docs.getdbt.com/docs/core/installation-overview): what dbt Core is and the ways to run it.
- [The dbt platform features](https://docs.getdbt.com/docs/cloud/about-cloud/dbt-cloud-features): what the paid product adds.
- [dbt pricing](https://www.getdbt.com/pricing): check the current plans here, prices change.
- [Understanding compute cost](https://docs.snowflake.com/en/user-guide/cost-understanding-compute) (Snowflake): credits, warehouse sizes, per-second billing.
- [Resource monitors](https://docs.snowflake.com/en/user-guide/resource-monitors): the spending cap. Your account has one, `TRIAL_GUARD`.

**Check yourself:**
1. If you run the same `dbt build` from your laptop and from dbt Cloud, does the Snowflake bill change? Why?
2. What does `AUTO_SUSPEND` on a warehouse do, and why does it matter more than where dbt runs?
3. Name two things you lose by running dbt only on your laptop (think: schedule, who else can run it, whose credentials).
4. When would a company pay for dbt Cloud instead of running dbt Core in its own Airflow?

---

## 2. Deployment

*Added 6 Nov 2026.*

**The idea:** deployment is how code goes from "works on my machine" to "runs on a schedule against
production data". Usually: a git branch, a pull request, automatic tests (CI) that build only what
changed into a temporary schema, a merge, then the scheduler runs the `prod` target.

**Read:**
- [Deploy dbt](https://docs.getdbt.com/docs/deploy/deployments): environments, jobs, how runs are scheduled.
- [Continuous integration in dbt](https://docs.getdbt.com/docs/deploy/continuous-integration): testing a pull request before it is merged ("slim CI", building only modified models).
- [Astronomer Cosmos](https://astronomer.github.io/astronomer-cosmos/): the library your Airflow DAG uses to turn each dbt model into an Airflow task.
- [Airflow production deployment](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/production-deployment.html): what changes when Airflow stops being `airflow standalone` on a laptop. On GCP the managed version is Cloud Composer.

**Check yourself:**
1. Open `dbt/profiles.yml` in your lab. What is different between the `dev` and `prod` targets, and what would you also separate in a real company?
2. What does a CI job do on a pull request, and which schema does it build into?
3. In `airflow/dags/shop_pipeline.py`, which target does the DAG use, and where does that choice come from?
4. How does new code reach a production Airflow: who copies the dbt project there, and when?

---

## 3. Service accounts for Snowflake, dbt and Airflow

*Added 6 Nov 2026.*

**The idea:** pipelines sign in as robot users, not as a person, so they do not break when someone
leaves or changes a password. In Snowflake that is a user with `TYPE = SERVICE`: no password login, no
MFA prompt, it signs in with a key pair (or OAuth). It is the same idea as a GCP service account with a
JSON key. You already have one: `PIPELINE_SVC` (made in `snowflake/00_setup.sql`, step 6; your key went
in during setup guide step 4).

**Read:**
- [CREATE USER](https://docs.snowflake.com/en/sql-reference/sql/create-user): the `TYPE` property (PERSON vs SERVICE).
- [Key-pair authentication and rotation](https://docs.snowflake.com/en/user-guide/key-pair-auth): why every user has two key slots.
- [Overview of access control](https://docs.snowflake.com/en/user-guide/security-access-control-overview): roles, grants, least privilege.
- [dbt Snowflake setup](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup): how dbt signs in with a key pair.
- [Airflow Snowflake connection](https://airflow.apache.org/docs/apache-airflow-providers-snowflake/stable/connections/snowflake.html): how Airflow stores the same credentials.

**Check yourself:**
1. In your lab, `PIPELINE_SVC` has both `LOADER` and `TRANSFORMER`. In a real company would the loading tool and dbt share one user? What would you gain by splitting them?
2. Where does the private key live in your lab, and where should it live on a production Airflow (hint: a secrets manager)?
3. How do you rotate the key without the pipeline failing for a minute? (Your account has the answer: look at `RSA_PUBLIC_KEY_2`.)
4. Your queries carry a `query_tag` (`dbt_dev` / `dbt_prod`). How would you use it to find out what the pipeline cost last week?

---

## 4. Data tests in Snowflake and dbt

*Added 6 Nov 2026.*

**The idea:** both ask "is this data right?", but at different moments. A **dbt data test** runs when dbt
runs: it is a SELECT that looks for bad rows, and it passes if it finds none. In `dbt build` a failed test
makes everything downstream skip, so bad data stops there. A **Snowflake data metric function (DMF)** is
attached to the table and runs on its own schedule, whoever changed the data. It returns a number and blocks
nothing. Add an *expectation* (for example `value = 0`) and Snowflake records a violation for you to act on.

**What you already know:** dbt's data tests are Dataform's assertions under another name. `uniqueKey` becomes
`unique`, `nonNull` becomes `not_null`, `rowConditions` becomes `dbt_utils.expression_is_true` (you have that
package), and a manual assertion becomes a singular test. Both tools pass on zero rows.

**Cost:** a dbt test is a query on your warehouse. A scheduled DMF runs on serverless compute, listed as "Data
Quality Monitoring" on the bill. Snowflake's page says a DMF you call by hand with a SELECT is not billed as one.

**Try it:** both of these return 0 on your data. Scheduling a DMF with an expectation also works on your trial
account: it was tried on a throwaway table, which is gone now.

```sql
select SNOWFLAKE.CORE.NULL_COUNT(select "TOTAL_PRICE" from RAW.SHOPIFY."ORDER");
select SNOWFLAKE.CORE.DUPLICATE_COUNT(select "ID" from RAW.SHOPIFY."ORDER");
```

**Read:**
- [Add data tests to your DAG](https://docs.getdbt.com/docs/build/data-tests) (dbt): singular and generic tests, the four built in.
- [store_failures](https://docs.getdbt.com/reference/resource-configs/store_failures) (dbt): keeps the failing rows in a table you can query.
- [dbt build](https://docs.getdbt.com/reference/commands/build): how a failed test makes downstream models skip, and how `warn` avoids it.
- [Introduction to data quality checks](https://docs.snowflake.com/en/user-guide/data-quality-intro) (Snowflake): DMFs, schedules, billing.
- [System data metric functions](https://docs.snowflake.com/en/user-guide/data-quality-system-dmfs): the ready-made ones.
- [Custom data metric functions](https://docs.snowflake.com/en/user-guide/data-quality-custom-dmfs): writing your own in SQL.
- [Use SQL to work with expectations](https://docs.snowflake.com/en/user-guide/data-quality-expectations): turning a DMF's number into pass or fail.
- [Test data quality](https://docs.cloud.google.com/dataform/docs/test-data) (Dataform): to set beside what you used before.

**Check yourself:**
1. Someone edits a row in `RAW.SHOPIFY."ORDER"` by hand at 3pm and dbt next runs at 6am. When does a dbt test see it, and when does a DMF on an hourly schedule?
2. `assert_order_total_matches_lines` has `severity: warn`. In `dbt build`, what happens downstream of `fct_orders` with it at `warn`, and at `error`? Which of your tests should be allowed to stop the pipeline?
3. A table loads once a day but its DMF runs every hour. Which schedule setting runs it only when the table changes? (Look for `TRIGGER_ON_CHANGES`.)
4. A table in RAW is loaded by another team's tool. Would you test it with a dbt source test, a DMF, or both? What does each catch that the other misses?

---

## 5. Immutability assertions

*Added 6 Nov 2026.*

**First, the name:** "immutability assertion" is not a named feature in dbt, Snowflake or Dataform. It is not
in their testing pages, and web searches found no standard definition. So this section is a reading of the
words, not a quoted definition: a check that rows which should never change after they are written really have
not changed. If you met the phrase somewhere specific, send Pippa where and this section will be lined up with it.

**The idea:** ordinary tests only look at the table as it is now. If someone rewrites an old order total from
40 to 30, `not_null` and `unique` still pass, because 30 is a perfectly valid value. To catch that you have to
compare with an earlier state of the table. New rows are fine; changed or deleted old rows fail.

**Way 1, Snowflake Time Travel:** compare the table with itself an hour ago (BigQuery's `FOR SYSTEM_TIME AS OF`
is the same idea). This returns the old version of every row changed or deleted in that hour. Rows added since
do not appear.

```sql
select * from RAW.SHOP.ORDERS at(offset => -3600)
minus
select * from RAW.SHOP.ORDERS;
```

Tested on your account: on a throwaway table, an added row gave 0 rows, and an update plus a delete returned
exactly those 2 rows. Saved in `dbt/tests/` with `{{ source('shop', 'orders') }}` it ran as a normal dbt test
and passed. The limit: your account keeps 1 day of history (`DATA_RETENTION_TIME_IN_DAYS`), so an offset of
100,000 seconds, about 28 hours, fails with an error.

**Way 2, a saved fingerprint:** `select hash_agg(*) from <table> where <closed month>` gives one number for all
those rows. Save it, and compare the next time. This is how you can say "January never changes" months later,
past Time Travel's reach. It tells you that something changed, not which row.

**Way 3, a dbt snapshot:** snapshot the table with `strategy: check` and `check_cols: all`. The test is then
`select * from <snapshot> where dbt_valid_to is not null`, because a filled `dbt_valid_to` means that row
changed. Two catches: it only sees differences between two `dbt snapshot` runs, and deleted rows are ignored
unless you set `hard_deletes`.

**Way 4, stop it instead of spotting it:** give each role only what it needs. On your account `TRANSFORMER` has
only SELECT on the `RAW.SHOPIFY` tables, so dbt cannot rewrite them. `LOADER` owns them, so it still can.

**Do not confuse it with Snowflake's frozen regions:** this is the closest thing with a similar name. `FROZEN
WHERE` on a dynamic table was "previously named immutability constraints", and the old `IMMUTABLE WHERE` syntax
still works (both ran on your account, on a throwaway table). dbt's config for it is `immutable_where`, from dbt
1.11; your lab pins 1.12.6. It tells Snowflake which rows to skip during a refresh, to save cost. It is not a
check: nothing tells you if a row changed, and the docs say you can still INSERT, UPDATE, MERGE or DELETE into
frozen rows. Your lab has no dynamic tables, so this part is reading only.

**Read:**
- [Understanding and using Time Travel](https://docs.snowflake.com/en/user-guide/data-time-travel) (Snowflake): `AT(...)` and how long history is kept.
- [HASH_AGG](https://docs.snowflake.com/en/sql-reference/functions/hash_agg) (Snowflake): one number for a set of rows, and why it is used to spot changes.
- [Add snapshots to your DAG](https://docs.getdbt.com/docs/build/snapshots) (dbt): `check_cols`, `dbt_valid_to`, `hard_deletes`.
- [Frozen regions and backfill](https://docs.snowflake.com/en/user-guide/dynamic-tables/frozen-regions) (Snowflake): the feature that used to be called immutability constraints.
- [Snowflake configurations](https://docs.getdbt.com/reference/resource-configs/snowflake-configs) (dbt): `immutable_where`, in the dynamic tables section.

**Check yourself:**
1. Someone rewrites a valid value in an old row of `fct_orders`. Which tests in your lab would notice today? Which of the four ways would, and how soon?
2. `fct_orders` only reprocesses orders whose `updated_at` is newer than what it holds, then merges on `order_id`. A source order changes but its `updated_at` does not. What does `fct_orders` show, and would `dbt build` tell you?
3. Run `dbt build --full-refresh`, then the Time Travel check on `fct_orders`. What happens, and why? The error message says it.
4. Time Travel reaches back 1 day on your account. In June, how would you prove January's orders never changed? What would you save, and where?
5. Of `RAW.SHOPIFY."ORDER"`, `RAW.META_ADS.AD_HISTORY` and `fct_orders`, which would you assert as immutable, and from what age? Think about a refund on an old order.
