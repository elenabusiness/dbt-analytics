# Shopify + Meta Ads practice data

A year of made-up data for a fictional UK coffee brand, **Fernhill Coffee**: its Shopify store and its Meta (Facebook
and Instagram) ad account. **Already loaded** into your account, in `RAW.SHOPIFY` and `RAW.META_ADS`.

- **Period:** Meta days 1 Nov 2025 to 31 Oct 2026; Shopify orders up to the "last sync", 1 Nov 2026 early morning.
- **Shape:** modelled on how an ELT connector (Fivetran-style) lands these two sources: one table per API object,
  `*_HISTORY` tables that keep every version of a campaign, ad set and ad, JSON kept as `VARIANT`, and the
  connector's own columns `_fivetran_synced` and `_fivetran_deleted`. Close to the real thing, not an exact copy of
  either connector. Every table also has this lab's audit columns `_file_name`, `_file_row`, `_loaded_at`.
- **Linked like real life:** ads drive clicks, some clicks become Shopify orders, and those orders carry the ad's
  UTM parameters in `landing_site`. Meta also reports its own purchase numbers, and they don't match Shopify's.
- **Size:** about 8,300 orders, 13,100 order lines, 5,000 customers, 3,500 ad-days, £48.6k of ad spend.

Drills on this data are section 6 of the Exercises doc (answers: section 6 of the Answers doc).

## Shopify (`RAW.SHOPIFY`)

| Table | One row per | Key columns |
|---|---|---|
| `SHOP` | the store | `currency` (GBP), `iana_timezone` (Europe/London), `taxes_included` |
| `CUSTOMER` | customer account | `id`, `email`, `default_address` (VARIANT), `orders_count`, `total_spent` (Shopify's own lifetime counters) |
| `PRODUCT` | product | `id`, `title`, `product_type` (Coffee, Equipment, Gift Card), `status` |
| `PRODUCT_VARIANT` | sellable variant (250g, 1kg, colour) | `id`, `product_id`, `sku`, `price` (today's price) |
| `"ORDER"` | order | `id`, `name` (#1001), `customer_id`, `created_at` (UTC), `financial_status`, `cancelled_at`, `total_price`, `presentment_currency`, `total_price_set` / `discount_codes` / `note_attributes` (VARIANT), `source_name`, `landing_site`, `test` |
| `ORDER_LINE` | line on an order | `id`, `order_id`, `variant_id`, `quantity`, `price` (the price paid then), `total_discount`, `gift_card`, `taxable` |
| `REFUND` | refund event | `id`, `order_id`, `created_at` |
| `ORDER_LINE_REFUND` | refunded line | `refund_id`, `order_line_id`, `quantity`, `subtotal` |
| `TRANSACTION` | payment event | `order_id`, `refund_id`, `kind` (sale, refund, authorization, void), `status`, `amount`, `currency` |

`ORDER` is a reserved word in SQL, so this table must always be written quoted: `raw.shopify."ORDER"`.
Unquoted, the query fails to compile (checked on your account).

Prices include VAT (UK). Coffee beans are zero-rated for VAT; equipment and shipping carry 20%.

## Meta Ads (`RAW.META_ADS`)

| Table | One row per | Key columns |
|---|---|---|
| `ACCOUNT_HISTORY` | ad account version | `currency`, `timezone_name` |
| `CAMPAIGN_HISTORY` | campaign **version** | `id`, `name`, `objective`, `status`, `daily_budget`, `updated_time` |
| `AD_SET_HISTORY` | ad set version | `id`, `campaign_id`, `daily_budget`, `optimization_goal`, `targeting` (VARIANT) |
| `AD_HISTORY` | ad version | `id`, `ad_set_id`, `campaign_id`, `creative_id`, `status` |
| `CREATIVE_HISTORY` | creative | `id`, `url_tags` (the UTM template the ad appends to its link) |
| `BASIC_AD` | ad per day | `ad_id`, `date`, `spend`, `impressions`, `inline_link_clicks`, `reach`, `frequency` |
| `BASIC_AD_ACTIONS` | ad per day per action type | `ad_id`, `date`, `action_type`, `value`, `_7_d_click`, `_1_d_view` |
| `BASIC_AD_ACTION_VALUES` | the same, in money | `ad_id`, `date`, `action_type`, `value`, `_7_d_click`, `_1_d_view` |

How they join: `BASIC_AD.ad_id` → `AD_HISTORY.id` → `AD_HISTORY.campaign_id` → `CAMPAIGN_HISTORY.id`.
`*_HISTORY` tables hold several rows per id: pick the version you need, never join them as they are.

## How Meta and Shopify meet

An order that came from an ad has a `landing_site` like
`/collections/coffee?utm_source=facebook&utm_medium=paid_social&utm_campaign=Retargeting%20%7C%2030d%20visitors&utm_content=120200000001010882&fbclid=...`:
`utm_campaign` is the campaign's name **at the time of the click**, URL-encoded, and `utm_content` is the ad's id.
Not every ad was tagged properly; finding which is drill 6.3.

## Reloading it

You don't need to: it is loaded. To rebuild it from scratch (same numbers every time, the generator is seeded):

```bash
source .env && source .venv-dbt/bin/activate
python scripts/generate_marketing_data.py      # writes data/raw/shopify/ and data/raw/meta_ads/
python scripts/load_marketing.py               # creates the tables (snowflake/02_raw_shopify_meta.sql) and loads
```

Run the loader twice: the second run loads nothing, as with `load_raw.py`.

## Ideas for your own dbt work on it

- `models/staging/shopify/` and `models/staging/meta_ads/`: sources with freshness on `_fivetran_synced`, one
  staging model per table, the `*_HISTORY` tables reduced to current versions (and a dated version table for
  as-of joins), `"ORDER"` renamed to something sane.
- `fct_ad_performance` (ad x day: spend, clicks, Meta purchases) and `fct_orders_attributed` (order, UTM source,
  campaign by ad id).
- `mart_marketing_daily`: spend, orders and revenue per day in **one** time zone, with ROAS both ways.
- Add the two load steps to the Airflow DAG as tasks before the dbt task group.
