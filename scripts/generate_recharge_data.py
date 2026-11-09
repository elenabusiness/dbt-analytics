"""Generate Recharge (subscription app) practice data for Fernhill Coffee, on top of the Shopify practice data.

Reads data/raw/shopify/*.csv (run generate_marketing_data.py first) and writes data/raw/recharge/*.csv:
customers, addresses, subscriptions, orders. Every Recharge row points at a real Shopify customer, order and variant
through the `external_*_id` objects, so a model can join the two sources the way a real pipeline does.

Shape: the way Stitch lands Recharge in a warehouse. One table per API object, nested objects and arrays kept as
VARIANT (customer, external_order_id, line_items ...), Stitch's own _sdc_* columns. Close to the real thing, not an
exact copy.

Deliberate traps (documented in docs/RECHARGE_DATA.md):
  - status values are upper case (ACTIVE / CANCELLED / EXPIRED), interval units lower case (day / week / month);
  - line_items prices are JSON strings ("9.50"), order totals are numbers;
  - external ids are strings inside JSON, Shopify's ids are numbers;
  - SUBSCRIPTIONS keeps an older version of some cancelled subscriptions (two rows for one id);
  - a few Shopify orders with source_name '294517' (the app's id) have no Recharge order, and many Recharge orders
    went through the normal web checkout (source_name 'web').

Deterministic (fixed seed): every run writes the same files.
"""
import csv
import hashlib
import json
import os
import random
import statistics
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SRC = os.path.join(ROOT, "data", "raw", "shopify")
OUT = os.path.join(ROOT, "data", "raw", "recharge")
R = random.Random(20261105)
UTC = timezone.utc
SYNCED = datetime(2026, 11, 1, 5, 47, 9, tzinfo=UTC)            # Stitch's last Recharge extraction
TODAY = SYNCED.date()


def read(table):
    p = os.path.join(SRC, f"{table}.csv")
    if not os.path.exists(p):
        raise SystemExit(f"missing {p} - run: python scripts/generate_marketing_data.py")
    with open(p, newline="") as f:
        return list(csv.DictReader(f))


def ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC) if s else None


def iso(dt):
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def money(x):
    return f"{x:.2f}"


_seq = [1_730_440_000_000_000_000]


def sdc(when=None):
    """Stitch's columns: extraction/receipt/batch times and a sequence that grows with every row version."""
    t = when or (SYNCED - timedelta(minutes=R.randint(0, 50)))
    _seq[0] += R.randint(1_000, 90_000)
    return dict(_sdc_extracted_at=iso(t), _sdc_received_at=iso(t + timedelta(seconds=R.randint(1, 40))),
                _sdc_batched_at=iso(t + timedelta(seconds=R.randint(41, 300))), _sdc_sequence=_seq[0], _sdc_table_version=None)


_ids = {}


def nid(kind, start):
    _ids[kind] = _ids.get(kind, start) + R.randint(1, 7)
    return _ids[kind]


def write(table, rows, cols):
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, f"{table}.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            vals = []
            for c in cols:
                v = r.get(c)
                if isinstance(v, (dict, list)):
                    v = json.dumps(v, separators=(",", ":"), ensure_ascii=False)
                elif isinstance(v, bool):
                    v = "true" if v else "false"
                elif isinstance(v, float):
                    v = f"{v:.2f}"
                vals.append("" if v is None else v)
            w.writerow(vals)
    print(f"recharge/{table}.csv".ljust(40), f"{len(rows):>7d} rows")


# ─────────────────────────── Shopify, as already generated ───────────────────────────
s_orders = read("order")
s_lines = read("order_line")
s_customers = {c["id"]: c for c in read("customer")}
s_variants = {v["id"]: v for v in read("product_variant")}
s_products = {p["id"]: p for p in read("product")}
lines_by_order = defaultdict(list)
for l in s_lines:
    lines_by_order[l["order_id"]].append(l)
for ls in lines_by_order.values():
    ls.sort(key=lambda l: int(l["id"]))


def ptype(line):
    return s_products[s_variants[line["variant_id"]]["product_id"]]["product_type"]


def subscribable(line):                      # beans and paper filters can be put on a subscription
    return (ptype(line) == "Coffee" and not line["sku"].startswith("FLIGHT")) or line["sku"].startswith("FIL")


GRAMS = lambda sku: 250 if sku.endswith("250") else 1000 if sku.endswith("1K") else 400 if sku.startswith("FLIGHT") else \
    120 if sku.startswith("FIL") else 0 if sku.startswith("GIFT") else 3200 if sku.startswith("GRD") else 900

orders_by_customer = defaultdict(list)
for o in s_orders:
    if o["customer_id"] and o["test"] != "true" and o["source_name"] in ("web", "294517"):
        orders_by_customer[o["customer_id"]].append(o)
for os_ in orders_by_customer.values():
    os_.sort(key=lambda o: o["created_at"])

# ─────────────────────────── who subscribes ───────────────────────────
app_customers = {o["customer_id"] for o in s_orders if o["source_name"] == "294517" and o["customer_id"]}
subscribers = []
for cid, os_ in orders_by_customer.items():
    eligible = [o for o in os_ if any(subscribable(l) for l in lines_by_order[o["id"]])]
    if not eligible:
        continue
    if cid in app_customers or (len(eligible) >= 2 and R.random() < 0.5) or (len(eligible) == 1 and R.random() < 0.07):
        subscribers.append(cid)
subscribers.sort(key=lambda c: orders_by_customer[c][0]["created_at"])

INTERVALS = [((1, "month"), 46), ((2, "week"), 10), ((4, "week"), 9), ((30, "day"), 6), ((2, "month"), 18),
             ((6, "week"), 5), ((3, "month"), 6)]
GRINDS = ["Whole bean", "Whole bean", "Whole bean", "Filter", "V60", "Espresso", "Cafetiere", "Aeropress"]
REASONS = [("Too much coffee at home", 24), ("Price", 14), ("Trying other roasters", 12), ("I only wanted one bag", 10),
           ("Moving abroad", 3), ("Delivery problems", 4), ("Other reason", 18), ("Max number of charge attempts reached", 5)]


def days_of(freq, unit):
    return freq * (1 if unit == "day" else 7 if unit == "week" else 30.4)


def add_interval(d, freq, unit):
    if unit == "day":
        return d + timedelta(days=freq)
    if unit == "week":
        return d + timedelta(weeks=freq)
    m = d.month - 1 + freq
    y, m = d.year + m // 12, m % 12 + 1
    for day in (d.day, 30, 29, 28):
        try:
            return d.replace(year=y, month=m, day=day)
        except ValueError:
            continue


def nearest_interval(gap_days):
    return min((iv for iv, _ in INTERVALS), key=lambda iv: abs(days_of(*iv) - gap_days))


rc_customers, rc_addresses, rc_subs, rc_orders = [], [], [], []
sub_versions = 0

for cid in subscribers:
    sc = s_customers[cid]
    os_ = orders_by_customer[cid]
    first_i = next(i for i, o in enumerate(os_) if any(subscribable(l) for l in lines_by_order[o["id"]]))
    picked = [os_[first_i]] + [o for o in os_[first_i + 1:] if o["source_name"] == "294517" or R.random() < 0.85]
    first = picked[0]
    t0 = ts(first["created_at"])

    # Recharge customer + address
    rcid = nid("customer", 118_400_000)
    addr = json.loads(sc["default_address"]) if sc["default_address"] else {}
    aid = nid("address", 151_700_000)
    rc_addresses.append(dict(id=aid, customer_id=rcid, first_name=sc["first_name"], last_name=sc["last_name"],
                             address1=f"{R.randint(1, 180)} {R.choice(['High St', 'Station Rd', 'Church Lane', 'Mill Rd', 'Park Ave', 'Victoria Rd'])}",
                             city=addr.get("city"), province=addr.get("province_code"), country_code=addr.get("country_code"),
                             zip=addr.get("zip"), phone=sc["phone"] or None, created_at=iso(t0 - timedelta(seconds=40)),
                             updated_at=iso(t0 - timedelta(seconds=40)), **sdc()))
    chash = hashlib.sha1(f"{rcid}".encode()).hexdigest()[:20]

    # subscriptions: one, sometimes two (two subscribable lines on the first order)
    first_sub_lines = [l for l in lines_by_order[first["id"]] if subscribable(l)]
    n_subs = 2 if len(first_sub_lines) >= 2 and R.random() < 0.45 else 1
    if len(picked) >= 2:
        gaps = [(ts(b["created_at"]) - ts(a["created_at"])).days for a, b in zip(picked, picked[1:])]
        freq, unit = nearest_interval(statistics.median(gaps))
    else:
        freq, unit = R.choices([iv for iv, _ in INTERVALS], [w for _, w in INTERVALS])[0]
    subs = []
    for k in range(n_subs):
        subs.append(dict(id=nid("sub", 412_300_000), k=k, freq=freq, unit=unit, created=t0, lines=[],
                         grind=R.choice(GRINDS), cancel_before=None))
    if n_subs == 2 and len(picked) >= 3 and R.random() < 0.4:      # the second one dropped part-way through
        subs[1]["cancel_before"] = ts(picked[R.randint(1, len(picked) - 1)]["created_at"])

    # Recharge orders: each picked Shopify order, its lines tagged subscription or one-time
    cust_orders = []
    for n, so in enumerate(picked):
        t = ts(so["created_at"])
        live = [s for s in subs if s["cancel_before"] is None or t < s["cancel_before"]]
        items, used = [], 0
        for l in lines_by_order[so["id"]]:
            if subscribable(l) and used < len(live):
                s = live[used]
                used += 1
                s["lines"].append((t, l))
                pid, ptype_ = s["id"], "subscription"
                props = [{"name": "grind", "value": s["grind"]}] if ptype(l) == "Coffee" else []
            else:
                pid, ptype_, props = nid("onetime", 433_900_000), "onetime", []
            q, price, disc = int(l["quantity"]), float(l["price"]), float(l["total_discount"])
            taxable = l["taxable"] == "true"
            total = round(price * q - disc, 2)
            items.append({"purchase_item_id": pid, "purchase_item_type": ptype_,
                          "external_product_id": {"ecommerce": l["product_id"]},
                          "external_variant_id": {"ecommerce": l["variant_id"]},
                          "sku": l["sku"], "title": l["title"], "variant_title": l["variant_title"], "quantity": q,
                          "unit_price": money(price), "total_price": money(total), "taxable": taxable,
                          "tax_due": money(round(total * 20 / 120, 2) if taxable else 0.0), "grams": GRAMS(l["sku"]),
                          "properties": props})
        status = "CANCELLED" if so["cancelled_at"] else "REFUNDED" if so["financial_status"] == "refunded" else "SUCCESS"
        refunds = float(so["total_price"]) if status == "REFUNDED" else \
            round(float(so["total_price"]) * R.choice([0.2, 0.25, 0.33, 0.5]), 2) if so["financial_status"] == "partially_refunded" else 0.0
        kind = "CHECKOUT" if n == 0 else "RECURRING"
        cust_orders.append(dict(
            id=nid("order", 561_200_000), address_id=aid,
            charge={"id": nid("charge", 781_500_000), "external_transaction_id": {"payment_processor": "ch_" + hashlib.sha1(so["id"].encode()).hexdigest()[:24]}},
            created_at=so["created_at"], processed_at=so["processed_at"],
            scheduled_at=iso(datetime.combine(t.date(), datetime.min.time(), UTC)) if kind == "RECURRING" else so["created_at"],
            updated_at=so["updated_at"], currency=so["presentment_currency"],
            customer={"id": rcid, "email": sc["email"], "external_customer_id": {"ecommerce": cid}, "hash": chash},
            discounts=json.loads(so["discount_codes"]) if so["discount_codes"] else [],
            external_order_id={"ecommerce": so["id"]}, external_order_name={"ecommerce": so["name"]},
            external_order_number={"ecommerce": so["order_number"]},
            is_prepaid=False, line_items=items,
            shipping_address={"address1": rc_addresses[-1]["address1"], "city": addr.get("city"), "province": addr.get("province_code"),
                              "country_code": addr.get("country_code"), "zip": addr.get("zip")},
            status=status, subtotal_price=float(so["subtotal_price"]), tags="Subscription First Order" if kind == "CHECKOUT" else "Subscription Recurring Order",
            total_discounts=float(so["total_discounts"]), total_price=float(so["total_price"]), total_refunds=refunds,
            total_tax=float(so["total_tax"]), type=kind, **sdc()))
    rc_orders.extend(cust_orders)

    # subscription rows: today's state (and for some cancelled ones, the older ACTIVE version Stitch also kept)
    active_n = 0
    for s in subs:
        if not s["lines"]:                                   # never charged: the same lines went to the first subscription
            continue
        t_last, l_last = s["lines"][-1]
        nxt = add_interval(t_last.date(), s["freq"], s["unit"])
        gap = days_of(s["freq"], s["unit"])
        xmas = l_last["sku"].startswith("XMS")
        if xmas:
            status = "EXPIRED"
        elif s["cancel_before"] is not None:
            status = "CANCELLED"
        elif (TODAY - t_last.date()).days > 2.2 * gap or (len(s["lines"]) == 1 and (TODAY - t_last.date()).days > 1.3 * gap and R.random() < 0.75):
            status = "CANCELLED"
        else:
            status = "ACTIVE"
        cancelled_at = None
        if status == "CANCELLED":
            ceiling = s["cancel_before"] or min(datetime.combine(nxt, datetime.min.time(), UTC), SYNCED - timedelta(hours=2))
            span = max(3600, int((ceiling - t_last).total_seconds()))
            cancelled_at = t_last + timedelta(seconds=R.randint(int(span * 0.2), span - 600 if span > 1200 else span))
        while status == "ACTIVE" and nxt < TODAY:              # skipped charges roll the date forward
            nxt = add_interval(nxt, s["freq"], s["unit"])
        reason = R.choices([r for r, _ in REASONS], [w for _, w in REASONS])[0] if status == "CANCELLED" else None
        updated = max(t_last + timedelta(hours=R.randint(1, 8)), cancelled_at or t_last)
        v = s_variants[l_last["variant_id"]]
        row = dict(id=s["id"], address_id=aid, customer_id=rcid, analytics_data={"utm_params": []},
                   cancellation_reason=reason,
                   cancellation_reason_comments=R.choice([None, None, None, "switching to decaf", "too many bags piling up", "will be back after Christmas"]) if reason else None,
                   cancelled_at=iso(cancelled_at), charge_interval_frequency=s["freq"], created_at=iso(s["created"]),
                   expire_after_specific_number_of_charges=len(s["lines"]) if xmas else None,
                   external_product_id={"ecommerce": l_last["product_id"]}, external_variant_id={"ecommerce": l_last["variant_id"]},
                   has_queued_charges=status == "ACTIVE", is_prepaid=False, is_skippable=True, is_swappable=True,
                   max_retries_reached=reason == "Max number of charge attempts reached",
                   next_charge_scheduled_at=nxt.isoformat() if status == "ACTIVE" else None,
                   order_day_of_month=None, order_day_of_week=None, order_interval_frequency=s["freq"], order_interval_unit=s["unit"],
                   presentment_currency="GBP", price=float(v["price"]), product_title=l_last["title"],
                   properties=[{"name": "grind", "value": s["grind"]}] if not l_last["sku"].startswith("FIL") else [],
                   quantity=int(l_last["quantity"]), sku=l_last["sku"], status=status, updated_at=iso(updated),
                   variant_title=l_last["variant_title"])
        if status == "CANCELLED" and R.random() < 0.10:
            old_t = t_last + timedelta(minutes=R.randint(5, 120))
            rc_subs.append(dict(row, cancellation_reason=None, cancellation_reason_comments=None, cancelled_at=None,
                                has_queued_charges=True, max_retries_reached=False, status="ACTIVE", updated_at=iso(old_t),
                                next_charge_scheduled_at=add_interval(t_last.date(), s["freq"], s["unit"]).isoformat(),
                                **sdc(old_t + timedelta(minutes=R.randint(30, 300)))))
            sub_versions += 1
        rc_subs.append(dict(row, **sdc()))
        active_n += status == "ACTIVE"

    total_n = sum(1 for s in subs if s["lines"])
    rc_customers.append(dict(id=rcid, email=sc["email"], external_customer_id={"ecommerce": cid}, first_name=sc["first_name"],
                             last_name=sc["last_name"], phone=sc["phone"] or None, hash=chash,
                             created_at=iso(t0 - timedelta(minutes=1)), updated_at=max(o["updated_at"] for o in cust_orders),
                             first_charge_processed_at=first["processed_at"], subscriptions_active_count=active_n,
                             subscriptions_total_count=total_n, has_valid_payment_method=active_n > 0 or R.random() < 0.6,
                             has_payment_method_in_dunning=False, tax_exempt=False, **sdc()))

SDC = ["_sdc_extracted_at", "_sdc_received_at", "_sdc_batched_at", "_sdc_sequence", "_sdc_table_version"]
COLS = {
    "customers": ["id", "email", "external_customer_id", "first_name", "last_name", "phone", "hash", "created_at", "updated_at",
                  "first_charge_processed_at", "subscriptions_active_count", "subscriptions_total_count",
                  "has_valid_payment_method", "has_payment_method_in_dunning", "tax_exempt"] + SDC,
    "addresses": ["id", "customer_id", "first_name", "last_name", "address1", "city", "province", "country_code", "zip", "phone",
                  "created_at", "updated_at"] + SDC,
    "subscriptions": ["id", "address_id", "customer_id", "analytics_data", "cancellation_reason", "cancellation_reason_comments",
                      "cancelled_at", "charge_interval_frequency", "created_at", "expire_after_specific_number_of_charges",
                      "external_product_id", "external_variant_id", "has_queued_charges", "is_prepaid", "is_skippable",
                      "is_swappable", "max_retries_reached", "next_charge_scheduled_at", "order_day_of_month",
                      "order_day_of_week", "order_interval_frequency", "order_interval_unit", "presentment_currency", "price",
                      "product_title", "properties", "quantity", "sku", "status", "updated_at", "variant_title"] + SDC,
    "orders": ["id", "address_id", "charge", "created_at", "processed_at", "scheduled_at", "updated_at", "currency", "customer",
               "discounts", "external_order_id", "external_order_name", "external_order_number", "is_prepaid", "line_items",
               "shipping_address", "status", "subtotal_price", "tags", "total_discounts", "total_price", "total_refunds",
               "total_tax", "type"] + SDC,
}
rc_subs.sort(key=lambda r: (r["id"], r["_sdc_sequence"]))
write("customers", rc_customers, COLS["customers"])
write("addresses", rc_addresses, COLS["addresses"])
write("subscriptions", rc_subs, COLS["subscriptions"])
write("orders", rc_orders, COLS["orders"])
print(f"subscriptions with an older version kept: {sub_versions}")
