# Recharge practice data (subscriptions)

Made-up subscription data for **Fernhill Coffee**, the same fictional brand as the Shopify practice data, from the
subscription app Recharge. **Already loaded** into your account, in `RAW.RECHARGE`. Raw tables only: the dbt sources
and models are yours to write.

- **Shape:** the way Stitch lands Recharge. One table per API object, nested objects and arrays kept as `VARIANT`,
  and Stitch's own columns `_sdc_extracted_at`, `_sdc_received_at`, `_sdc_batched_at`, `_sdc_sequence`,
  `_sdc_table_version`. Close to the real thing, not an exact copy. Every table also has the lab's audit columns
  `_file_name`, `_file_row`, `_loaded_at`.
- **Linked to Shopify:** every Recharge order is a real order in `RAW.SHOPIFY."ORDER"`, every line item is a real
  `ORDER_LINE`, and every customer is a real Shopify customer.
- **Size:** 1,234 customers, 1,455 subscriptions (1,558 rows), 2,389 orders, 3,865 order line items.

## Tables (`RAW.RECHARGE`)

| Table | One row per | Key columns |
|---|---|---|
| `CUSTOMERS` | subscriber | `id` (Recharge's id), `external_customer_id` (VARIANT: `{"ecommerce": "<Shopify customer id>"}`), `email`, `subscriptions_active_count` |
| `ADDRESSES` | delivery address | `id`, `customer_id`, `city`, `zip`, `country_code` |
| `SUBSCRIPTIONS` | subscription **version** | `id`, `customer_id`, `status`, `order_interval_frequency`, `order_interval_unit`, `charge_interval_frequency`, `next_charge_scheduled_at` (DATE), `cancelled_at`, `cancellation_reason`, `external_variant_id` (VARIANT), `updated_at` |
| `ORDERS` | order Recharge created or recorded | `id`, `type` (CHECKOUT = the order that started a subscription, RECURRING = a later charge), `status`, `customer` (VARIANT), `external_order_id` (VARIANT), `line_items` (VARIANT array), `total_price` |

Inside each element of `ORDERS.line_items`: `purchase_item_id` (the subscription id, or a one-time item's id),
`purchase_item_type` (`subscription` / `onetime`), `external_variant_id.ecommerce`, `external_product_id.ecommerce`,
`sku`, `quantity`, `unit_price`, `total_price`, `properties` (the grind).

## How it joins to Shopify

| Recharge | Shopify |
|---|---|
| `ORDERS.customer:external_customer_id:ecommerce` | `"ORDER".customer_id` / `CUSTOMER.id` |
| `ORDERS.external_order_id:ecommerce` | `"ORDER".id` |
| `line_items[n]:external_variant_id:ecommerce` | `ORDER_LINE.variant_id` |
| `line_items[n]:purchase_item_id` | `SUBSCRIPTIONS.id` (when `purchase_item_type` = `subscription`) |

```sql
select o.external_order_id:ecommerce::number   as shopify_order_id,
       li.value:purchase_item_id::number         as subscription_id,
       li.value:external_variant_id:ecommerce::number as shopify_variant_id
from raw.recharge.orders o,
     lateral flatten(input => o.line_items) li;      -- BigQuery: left join unnest(line_items)
```

## Things to watch (on purpose)

1. `SUBSCRIPTIONS` keeps **two rows for 103 ids**: an older ACTIVE version beside the CANCELLED one. Take the latest
   per `id` (by `_sdc_sequence` or `updated_at`) before joining, or every order line on those subscriptions doubles:
   3,865 line items become 4,038.
2. `status` is upper case (ACTIVE, CANCELLED, EXPIRED; orders SUCCESS, CANCELLED, REFUNDED). `order_interval_unit` is
   lower case (day, week, month).
3. Ids inside the JSON are strings (`"6900000000005"`); Shopify's ids are numbers. Cast one side.
4. Prices inside `line_items` are strings (`"8.50"`); the order totals are numbers.
5. EXPIRED subscriptions (Christmas Blend, a fixed number of charges) are not cancelled, and have no next charge.
6. 9 of the 184 Shopify orders with `source_name` = `294517` (Recharge's app id) have no Recharge order, and most
   Recharge orders came through the normal web checkout (`source_name` = `web`). Recharge's own tables are the list
   of subscription orders, not `source_name`.

## Check numbers (computed on your account)

| What | Number |
|---|---|
| Subscriptions, latest version per id | 1,455: ACTIVE 442, CANCELLED 980, EXPIRED 33 |
| Orders by type | CHECKOUT 1,234, RECURRING 1,155 |
| Line items | 3,865: subscription 2,651, onetime 1,214 |
| Line items that match a Shopify order line (customer + order + variant) | 3,865 of 3,865 |
| Active subscriptions' next charge | 1 Nov 2026 to 30 Jan 2027 |

## Reloading it

You don't need to. To rebuild from scratch (seeded, same numbers every time; it reads the Shopify CSVs, so generate
those first on a fresh copy):

```bash
source .env && source .venv-dbt/bin/activate
python scripts/generate_recharge_data.py       # writes data/raw/recharge/
python scripts/load_recharge.py                # creates the tables (snowflake/03_raw_recharge.sql) and loads
```
