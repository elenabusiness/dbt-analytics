# Shopify extras: shipping lines, order adjustments, disputes

Three more made-up tables for **Fernhill Coffee**, added next to the other Shopify tables. **Already loaded** in
`RAW.SHOPIFY`. Raw tables only: sources, tests and models are yours to write. None of the existing tables changed.

| Table | One row per | Rows |
|---|---|---|
| `ORDER_SHIPPING_LINE` | shipping line on an order | 8,004 |
| `ORDER_ADJUSTMENT` | refund money that is not on a refunded line (shipping, mostly) | 44 |
| `DISPUTES` | Shopify Payments chargeback or inquiry | 66 |

In BigQuery, Stitch kept shipping lines and adjustments as nested arrays you had to `UNNEST`. Here they are flat tables,
one row per array item, and the nested `*_set` money objects are flattened into columns too.

## `ORDER_SHIPPING_LINE`

Key columns: `id`, `order_id`, `title`, `code`, `source`, `carrier_identifier`, `price` and `discounted_price` (numbers,
GBP), `price_set` (VARIANT, both currencies).

Join on `order_shipping_line.order_id = "ORDER".id`.

Titles after `lower()`, with row counts:

| Title | Rows | Price |
|---|---|---|
| `free uk delivery` | 2,847 | £0 |
| `royal mail tracked 48` | 2,413 | £3.95 (£0 on a repeated line) |
| `royal mail 48` | 1,731 | £3.95 (£0 on a repeated line) |
| `an post ireland` | 282 | £3.95 (£0 on a repeated line) |
| `free ireland delivery` | 226 | £0 |
| `collect from the roastery` | 119 | £0 |
| `subscription shipping` | 112 | £3.95 |
| `wholesale delivery` | 107 | £3.95 or £0 |
| `dpd next day` | 96 | £0 |
| `free subscription shipping` | 71 | £0 |

**Traps:**
- 406 orders have no shipping line: 353 POS orders, the rest gift-card-only. An inner join loses them.
- The Royal Mail rate was renamed on 1 Mar 2026, and about 2% of titles are in capitals.
- 135 orders have two lines; on 39 of them both lines have the same title.

## `ORDER_ADJUSTMENT`

Key columns: `id`, `order_id`, `refund_id`, `kind`, `reason`, `amount`, `tax_amount`, then `amount_set_*` and
`tax_amount_set_*`, each with `shop_money` (GBP) and `presentment_money` (the customer's currency) amount and currency
code. Every money column is **text**, as in Shopify's API, and **negative** for money going back.

Join on `order_adjustment.refund_id = refund.id`.

| `kind` | Rows | `amount` | `tax_amount` |
|---|---|---|---|
| `shipping_refund` | 29 | -£95.41 | -£19.14 |
| `refund_discrepancy` | 15 | £0 | £0 |

**Traps:**
- `TRY_CAST` only takes text in Snowflake: `try_cast(1.5::number(12,2) as float)` is a compile error (checked on your
  account). That is fine here, because these columns are text.
- 9 rows, on refunds before 1 Jan 2026, have NULL in every `*_set` column. `amount` and `tax_amount` are still filled.
- 3 `shipping_refund` rows have `amount_set_shop_money_amount` = `0.00` while `amount` has the real value.
- `tax_amount_set_presentment_money_amount` is in the customer's currency. Summing it as if it were GBP gives **£16.79**:
  4 `shipping_refund` rows have no `*_set` value, and 2 are in EUR or USD. The real figure is **£19.14**.

## `DISPUTES`

Key columns: `id`, `order_id`, `type` (chargeback, inquiry), `status`, `reason`, `network_reason_code`, `amount` (text),
`currency`, `initiated_at`, `evidence_due_by`, `evidence_sent_on`, `finalized_on`. It is on orders paid through
`shopify_payments` only.

Join on `disputes.order_id = "ORDER".id`.

| `status` | Rows | Sum of `amount` as written | `finalized_on` |
|---|---|---|---|
| `lost` | 33 | 900.21 | set |
| `won` | 22 | 984.40 | set |
| `needs_response` | 5 | 288.60 | NULL |
| `under_review` | 4 | 77.50 | NULL |
| `accepted` | 1 | 13.45 | set |
| `charge_refunded` | 1 | 23.45 | set |

**Traps:**
- `amount` is in `currency`, so 3 `lost` rows are in EUR or USD and the 900.21 mixes currencies.
- `accepted` means the shop gave in, so that money is gone too, although the status is not `lost`.
- 7 orders have more than one dispute: 4 had an inquiry the shop won and then a chargeback it lost, and 3 lost two
  part chargebacks. Grouping by order sums the 3 correctly, and a status filter drops the 4 won inquiries.
- 4 `lost` orders were also part refunded, so subtracting refunds and disputes both can take the same money off twice.
- 1 `lost` row has no `order_id` (£24.50), so grouping by order gives a NULL group that no order joins to.

## Check numbers

Run on your account as `TRANSFORMER`:

- `sum(order_shipping_line.price)` = `sum("ORDER".shipping_price)` = **£18,091.00**, and they match on all 8,275 orders.
- For all 448 refunds, `order_line_refund.subtotal` plus the adjustment's `-(amount + tax_amount)` equals the refund's
  `transaction.amount` within 1p, after converting EUR at 1.17 and USD at 1.27.
- Lost disputes, grouped by `order_id`: **30 groups** (29 orders and the NULL one), **900.21** as written.

## Reloading it

You don't need to: it is loaded. To rebuild (same numbers every time, the generator is seeded):

```bash
source .env && source .venv-dbt/bin/activate
python scripts/generate_shopify_extras.py      # reads the Shopify CSVs, writes the three new ones next to them
python scripts/load_marketing.py               # loads only what isn't loaded yet
```
