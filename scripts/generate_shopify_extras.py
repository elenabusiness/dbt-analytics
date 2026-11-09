"""Generate three more Shopify landing tables for Fernhill Coffee, on top of the Shopify practice data.

Reads data/raw/shopify/*.csv (run generate_marketing_data.py first), changes none of them, and writes:

  data/raw/shopify/order_shipping_line.csv   one row per shipping line on an order
  data/raw/shopify/order_adjustment.csv      refund money that is not on a refunded line (shipping, mostly)
  data/raw/shopify/disputes.csv              Shopify Payments chargebacks and inquiries

They tie out to the existing tables, so they can be checked:
  - per order, SUM(order_shipping_line.price) = "ORDER".shipping_price;
  - per refund, SUM(order_line_refund.subtotal) + SUM(order_adjustment.amount + tax_amount), with the adjustment's
    sign flipped, = the refund's TRANSACTION.amount, in GBP;
  - every non-NULL disputes.order_id is an "ORDER".id paid through shopify_payments.

Deliberate traps (documented in docs/SHOPIFY_EXTRAS_DATA.md):
  - shipping: POS and gift-card-only orders have no shipping line, so an inner join loses them; titles change over time
    and in case; some orders have two lines, and a few repeat the same title;
  - adjustments: amounts are negative text; rows from before 2026 have no *_set columns; a few have shop money 0.00
    with the real value only in amount; *_presentment_money is in the customer's currency, not GBP; zero-value rows;
  - disputes: amounts are text in the customer's currency; "lost" is not the only way to lose the money
    ("accepted"); an inquiry and a chargeback can sit on one order; a lost dispute can sit on an already refunded order;
    one has no order_id; open ones have no finalized_on.

Deterministic (fixed seed): every run writes the same files.
"""
import csv
import json
import os
import random
from collections import defaultdict
from datetime import datetime, timedelta, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SHOP = os.path.join(ROOT, "data", "raw", "shopify")
R = random.Random(20261108)
UTC = timezone.utc
FX = {"GBP": 1.0, "EUR": 1.17, "USD": 1.27}          # the same rates the Shopify generator used


def read(table):
    path = os.path.join(SHOP, f"{table}.csv")
    if not os.path.exists(path):
        raise SystemExit(f"missing {path} - run generate_marketing_data.py first")
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


def iso(dt):
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def write(table, rows, cols):
    with open(os.path.join(SHOP, f"{table}.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            w.writerow(["" if r.get(c) is None else r[c] for c in cols])


orders = read("order")
order_by_id = {o["id"]: o for o in orders}
LAST_SYNC = max(ts(o["_fivetran_synced"]) for o in orders)


def synced():
    return iso(LAST_SYNC - timedelta(minutes=R.randint(0, 600)))


lines_by_order = defaultdict(list)
for l in read("order_line"):
    lines_by_order[l["order_id"]].append(l)
country = {c["id"]: json.loads(c["default_address"])["country_code"] for c in read("customer")}

# ─────────────────────────── ORDER_SHIPPING_LINE ───────────────────────────
RENAMED = datetime(2026, 3, 1, tzinfo=UTC)           # the carrier's rate was renamed in the checkout on this day
ship_rows = []


def ship_line(o, title, price, source="shopify", carrier=None):
    p = float(price)
    pres = o["presentment_currency"]
    ship_rows.append(dict(
        id=14_700_000_000_000 + len(ship_rows) * 3 + R.randint(0, 2), order_id=o["id"], title=title, code=title, source=source,
        carrier_identifier=carrier, price=f"{p:.2f}", discounted_price=f"{p:.2f}",
        price_set=json.dumps({"shop_money": {"amount": f"{p:.2f}", "currency_code": "GBP"},
                              "presentment_money": {"amount": f"{p * FX[pres]:.2f}", "currency_code": pres}}, separators=(",", ":")),
        _fivetran_synced=synced()))


def base_title(o, paid):
    ie = country.get(o["customer_id"]) == "IE"
    src = o["source_name"]
    if src == "shopify_draft_order":
        return "Wholesale delivery"
    if src == "294517":                              # the subscription app's orders
        return "Subscription shipping" if paid else "Free subscription shipping"
    if not paid:
        if R.random() < 0.03:
            return "Collect from the roastery"
        return "Free Ireland delivery" if ie else "Free UK delivery"
    if ie:
        return "An Post Ireland"
    title = "Royal Mail 48" if ts(o["created_at"]) < RENAMED else "Royal Mail Tracked 48"
    return title.upper() if R.random() < 0.02 else title


for o in orders:
    if o["source_name"] == "pos" or all(l["gift_card"] == "true" for l in lines_by_order[o["id"]]):
        continue                                     # nothing to ship, no shipping line (a shipping_price of 0)
    price = float(o["shipping_price"])
    title = base_title(o, price > 0)
    ship_line(o, title, price, source="Royal Mail" if title.lower().startswith("royal") else "shopify")
    roll = R.random()
    if roll < 0.012:                                 # customer service upgraded it: a second line at no charge
        ship_line(o, "DPD Next Day", 0, source="DPD", carrier="dpd_uk")
    elif roll < 0.016:                               # an order edit put the same line on again at no charge
        ship_line(o, title, 0)

# ─────────────────────────── ORDER_ADJUSTMENT ───────────────────────────
SET_COLUMNS_FROM = datetime(2026, 1, 1, tzinfo=UTC)  # the connector only started landing the *_set columns here
refund_subtotal = defaultdict(float)
for rl in read("order_line_refund"):
    refund_subtotal[rl["refund_id"]] += float(rl["subtotal"])
refund_tx = {t["refund_id"]: t for t in read("transaction") if t["refund_id"]}
refunds = read("refund")
adj_rows = []


def adjustment(r, kind, reason, amount, tax, shop_zero=False):
    o = order_by_id[r["order_id"]]
    pres = o["presentment_currency"]
    fx = FX[pres]
    row = dict(id=3_300_000_000_000 + len(adj_rows) * 5 + R.randint(0, 4), order_id=o["id"], refund_id=r["id"], kind=kind, reason=reason,
               amount=f"{amount:.2f}", tax_amount=f"{tax:.2f}", _fivetran_synced=synced())
    if ts(r["created_at"]) >= SET_COLUMNS_FROM:
        row.update(amount_set_shop_money_amount="0.00" if shop_zero else f"{amount:.2f}", amount_set_shop_money_currency_code="GBP",
                   amount_set_presentment_money_amount=f"{amount * fx:.2f}", amount_set_presentment_money_currency_code=pres,
                   tax_amount_set_shop_money_amount=f"{tax:.2f}", tax_amount_set_shop_money_currency_code="GBP",
                   tax_amount_set_presentment_money_amount=f"{tax * fx:.2f}", tax_amount_set_presentment_money_currency_code=pres)
    adj_rows.append(row)


shipping_refunds, plain_refunds = [], []
for r in refunds:
    fx = FX[order_by_id[r["order_id"]]["presentment_currency"]]
    left = round(float(refund_tx[r["id"]]["amount"]) / fx - refund_subtotal[r["id"]], 2)
    (shipping_refunds if left > 0 else plain_refunds).append((r, left))

recent = [r["id"] for r, _ in shipping_refunds if ts(r["created_at"]) >= SET_COLUMNS_FROM]
shop_zero = set(R.sample(recent, 3))                 # the connector wrote 0.00 where it had no conversion
for r, left in shipping_refunds:                     # the money the refund transaction has and the refund lines don't
    tax = round(left * 20 / 120, 2)                  # shipping carries 20% VAT, included in the price
    adjustment(r, "shipping_refund", "Shipping refund", -(left - tax), -tax, shop_zero=r["id"] in shop_zero)
for r, _ in R.sample(plain_refunds, 15):             # a discrepancy Shopify recorded and that came to nothing
    adjustment(r, "refund_discrepancy", "Refund discrepancy", 0.0, 0.0)
adj_rows.sort(key=lambda a: a["id"])

# ─────────────────────────── DISPUTES ───────────────────────────
paid_via_shopify = {t["order_id"] for t in read("transaction")
                    if t["kind"] == "sale" and t["status"] == "success" and t["gateway"] == "shopify_payments"}
eligible = [o for o in orders if o["id"] in paid_via_shopify and o["test"] == "false" and not o["cancelled_at"]
            and o["financial_status"] in ("paid", "partially_refunded") and ts(o["created_at"]) <= LAST_SYNC - timedelta(days=15)]
REASONS = (["fraudulent"] * 11 + ["product_not_received"] * 4 + ["product_unacceptable"] * 2
           + ["subscription_canceled", "credit_not_processed", "duplicate"])
CODES = {"fraudulent": "10.4", "product_not_received": "13.1", "product_unacceptable": "13.3", "subscription_canceled": "13.2",
         "credit_not_processed": "13.7", "duplicate": "12.6"}
disputes = []


def dispute(o, kind, status=None, share=1.0, after=None):
    """status None: drawn from the usual mix, and still open if the card network would not have finished by the last sync."""
    created = ts(o["created_at"]) if o else LAST_SYNC - timedelta(days=120)
    start = after or created
    initiated = min(start + timedelta(days=R.randint(12, 70), hours=R.randint(0, 23)), LAST_SYNC - timedelta(days=R.randint(1, 9)))
    finalized = initiated + timedelta(days=R.randint(25, 80))
    if status is None:
        status = R.choices(["won", "lost", "accepted", "charge_refunded"], [42, 34, 6, 6])[0]
        if finalized > LAST_SYNC:
            status = R.choice(["under_review", "needs_response"])
    elif finalized > LAST_SYNC:
        finalized = LAST_SYNC - timedelta(hours=R.randint(1, 48))
    is_open = status in ("under_review", "needs_response")
    reason = R.choice(REASONS)
    pres = o["presentment_currency"] if o else "GBP"
    total = float(o["total_price"]) if o else 24.50
    disputes.append(dict(
        order_id=o["id"] if o else None, type=kind, status=status, reason=reason, network_reason_code=CODES[reason],
        amount=f"{total * FX[pres] * share:.2f}", currency=pres, initiated_at=initiated,
        evidence_due_by=iso(initiated + timedelta(days=R.randint(14, 21))),
        evidence_sent_on=iso(initiated + timedelta(days=R.randint(1, 12))) if status in ("won", "lost", "under_review") else None,
        finalized_on=None if is_open else iso(finalized), shop_url="fernhillcoffee.example", _fivetran_synced=synced()))
    return initiated


pool = R.sample(eligible, len(eligible))
take = lambda n, keep=lambda o: True: [pool.pop(next(i for i, o in enumerate(pool) if keep(o))) for _ in range(n)]

for o in take(4):                                    # an inquiry the shop won, then the customer's bank charged back anyway
    dispute(o, "chargeback", "lost", after=dispute(o, "inquiry", "won"))
for o in take(3):                                    # two partial chargebacks on one order, both lost
    dispute(o, "chargeback", "lost", share=0.6, after=dispute(o, "chargeback", "lost", share=0.4))
for o in take(4, lambda o: o["financial_status"] == "partially_refunded"):
    dispute(o, "chargeback", "lost")                 # refunded in part AND charged back in full
for o in take(3, lambda o: o["presentment_currency"] != "GBP"):
    dispute(o, "chargeback", "lost")                 # lost, in the customer's currency
for o in take(44):
    dispute(o, "inquiry" if R.random() < 0.15 else "chargeback", share=0.5 if R.random() < 0.12 else 1.0)
dispute(None, "chargeback", "lost")                  # the API gave no order for this one

disputes.sort(key=lambda d: (d["initiated_at"], d["order_id"] or ""))
for i, d in enumerate(disputes):
    d["id"] = 8_800_000_000_000 + i * 7 + R.randint(0, 6)
    d["initiated_at"] = iso(d["initiated_at"])

write("order_shipping_line", ship_rows, ["id", "order_id", "title", "code", "source", "carrier_identifier", "price", "discounted_price",
                                         "price_set", "_fivetran_synced"])
write("order_adjustment", adj_rows, ["id", "order_id", "refund_id", "kind", "reason", "amount", "tax_amount",
                                     "amount_set_shop_money_amount", "amount_set_shop_money_currency_code",
                                     "amount_set_presentment_money_amount", "amount_set_presentment_money_currency_code",
                                     "tax_amount_set_shop_money_amount", "tax_amount_set_shop_money_currency_code",
                                     "tax_amount_set_presentment_money_amount", "tax_amount_set_presentment_money_currency_code",
                                     "_fivetran_synced"])
write("disputes", disputes, ["id", "order_id", "type", "status", "reason", "network_reason_code", "amount", "currency", "initiated_at",
                             "evidence_due_by", "evidence_sent_on", "finalized_on", "shop_url", "_fivetran_synced"])
print(f"order_shipping_line: {len(ship_rows)} rows, order_adjustment: {len(adj_rows)} rows, disputes: {len(disputes)} rows")
