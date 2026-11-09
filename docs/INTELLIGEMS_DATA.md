# Intelligems practice data (A/B tests)

Made-up A/B test data for **Fernhill Coffee**, the same fictional brand as the Shopify practice data, from the
testing app Intelligems. **Already loaded** into your account, in two places. Raw tables only: the dbt sources and
models are yours to write.

- **`RAW.INTELLIGEMS`**: Intelligems' order export. In BigQuery this was an external table over a bucket of CSV
  files, one file per export; here every export is loaded into one table.
- **`RAW.GOOGLE_SHEETS`**: one older test whose results were pasted into a Google Sheet, one tab per band. In
  BigQuery these were sheet-backed external tables; here each tab is a table.
- **Linked to Shopify:** every `order_id` is a real order in `RAW.SHOPIFY."ORDER"` (as text: `order_id = "ORDER".id::varchar`).
- Every table also has the lab's audit columns `_file_name`, `_file_row`, `_loaded_at`.

## `RAW.INTELLIGEMS.INTELLIGEMS_DATA_IMPORT_RAW`

One row per **test x order x export**. Someone downloaded each test's order export every Monday, and each export
lists every order in the test so far, so most orders appear several times.

| Column | What it is |
|---|---|
| `ig_id` | id of the row |
| `order_id` | Shopify order id, as text |
| `test_id`, `test_name` | the test |
| `variant_id`, `variant_name` | the group the order was in |
| `is_excluded` | Intelligems left the order out of the results (an outlier: order value more than 3 standard deviations from the test's mean) |
| `order_value_z_score` | that standard-deviation number, recomputed in every export |
| `loaded_at_ts` | when that export was taken: the column that tells exports apart |

| Test | Ran | Variants | Orders | Exports |
|---|---|---|---|---|
| Free shipping threshold | 2 Feb to 29 Mar 2026 | Control / Free shipping from £25 | 808 | 8, 9 Feb to 30 Mar |
| 1kg bag price | 16 Mar to 10 May 2026 | Control (£24.00) / £22.50 / £26.00 | 854 | 8, 23 Mar to 11 May |
| Subscribe & save discount | 1 Jun to 26 Jul 2026 | Control (10% off) / 15% off | 737 | 8, 8 Jun to 27 Jul |

## `RAW.GOOGLE_SHEETS.IG_OUT_OF_STOCK_<band>_ORDERS_TABLE`

Five tables, one per tab: `IG_OUT_OF_STOCK_0_35_ORDERS_TABLE`, `..._35_65_...`, `..._65_100_...`, `..._100_120_...`,
`..._120_PLUS_...`. One test (3 Aug to 27 Sep 2026, variants `Control` / `Fewer sizes when out of stock`), its
orders split by the customer's brew-quiz answer "cups per month": 0-35, 35-65, 65-100, 100-120, 120+. The band is
only in the table name, not in a column.

29 columns, the same in every tab. **All text except `is_outlier` (BOOLEAN)**, as a sheet-backed table is. The ones
the old pipeline uses: `variation_name` (the variant), `order_id`, `is_outlier`. The rest: `order_name` (`#7395`),
`customer_id`, `order_created_time` (`'2026-08-03 13:42:09'`, London time, no zone), money columns as text with a
pound sign (`product_list_price` `'£43.80'`, `net_revenue`, `gross_profit` ...), `total_units`,
`subscription_order_type`, `new_vs_returning_visitor`, `device_type`, `channel`, `timezone`, `label`.

## Things to watch (on purpose)

1. **The export is cumulative.** 11,076 rows, but only 2,399 test x order pairs. Take the latest row per **test and
   order** (by `loaded_at_ts`) before anything else.
2. **`is_excluded` can change between exports**, because the z-score is recomputed as orders come in: 25 test x order
   pairs flip. Only the latest export's value counts.
3. **175 orders are in two tests**: Free shipping threshold and 1kg bag price overlapped from 16 to 29 Mar. The
   tests' last exports are on different days (30 Mar and 11 May), so ranking by `loaded_at_ts` per **order** alone
   keeps only the 1kg bag price row and drops the order's other test. Partition by test and order.
4. **One test was renamed**: the 1kg bag price test is called `1kg price test` in its first exports (679 rows). Group
   by `test_id`, not `test_name`, or take the name from the latest export.
5. **Sheet tabs include both ends**, so a customer who answered exactly 35 or 65 is on two tabs: 21 orders (14 on
   0-35 and 35-65, 7 on 35-65 and 65-100).
6. **Empty rows at the bottom of every tab** (the sheet range picks up blank rows): 15 rows where every column is
   NULL. They change a `count(*)`.
7. **8 real rows have `is_outlier` blank** (NULL). `where not is_outlier` drops them without a word, because
   `not NULL` is NULL. Decide what a blank means and say so (`coalesce`).
8. **Text that looks like numbers**: money is `'£43.80'` and the z-score is `'0.3485'`. Strip the pound sign before a
   cast (`try_to_number(replace(x, '£', ''), 10, 2)`).
9. Test names sort as text: `'IG - 100-120'` comes before `'IG - 36-65'`. A rule like "keep the first test name
   alphabetically" picks a different band at 100 than at 35 or 65 (no order sits on 100 or 120 in this data).

## Check numbers (computed on your account)

| What | Number |
|---|---|
| Export rows / orders / test x order pairs | 11,076 / 2,224 / 2,399 |
| Latest row per test x order: excluded | 69 of 2,399 |
| Latest per test x order, not excluded: orders / orders in two tests | 2,158 / 172 |
| The old pipeline's logic (rank per order only): orders / orders in two tests | 2,158 / 0 (172 orders lose their Free shipping test) |
| Sheet rows, all five tabs / empty rows / real rows | 832 / 15 / 817 |
| Real rows: distinct orders / orders on two tabs | 796 / 21 |
| Orders with `is_outlier` TRUE / blank | 15 / 8 |
| The old pipeline's logic (`where not is_outlier`, first test name per order) | 773 orders: Control 390, Fewer sizes 383 |
| Same, counting a blank `is_outlier` as not an outlier | 781 orders |
| Order ids not found in `RAW.SHOPIFY."ORDER"` | 0 (both sources) |

## How it joins

| These tables | Shopify / the old pipeline |
|---|---|
| `INTELLIGEMS_DATA_IMPORT_RAW.order_id` | `"ORDER".id` (cast one side); the old pipeline's Intelligems import model reads this table |
| `IG_OUT_OF_STOCK_*_ORDERS_TABLE.order_id` | `"ORDER".id`; the old pipeline's out-of-stock model unions the five tabs |

## Reloading it

You don't need to. To rebuild from scratch (seeded, same numbers every time; it reads the Shopify and Recharge CSVs,
so generate those first on a fresh copy):

```bash
source .env && source .venv-dbt/bin/activate
python scripts/generate_intelligems_data.py     # writes data/raw/intelligems/ and data/raw/google_sheets/
python scripts/load_intelligems.py              # creates the tables (snowflake/04_raw_intelligems.sql) and loads
```
