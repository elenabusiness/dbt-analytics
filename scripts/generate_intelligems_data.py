"""Generate Intelligems (A/B testing app) practice data for Fernhill Coffee, on top of the Shopify practice data.

Reads data/raw/shopify/*.csv and data/raw/recharge/orders.csv (run generate_marketing_data.py and
generate_recharge_data.py first) and writes two landing sets:

  data/raw/intelligems/intelligems_data_import_raw.csv
      Intelligems' order export, the way it lands when someone drops each weekly export file into a bucket and the
      warehouse reads the whole bucket: one row per test x order x EXPORT. Each export is cumulative (every order in
      the test so far), so most orders appear several times, once per export, told apart by loaded_at_ts.

  data/raw/google_sheets/ig_out_of_stock_<band>_orders_table.csv   (five files, one per tab)
      One older test whose results were pasted from Intelligems into a Google Sheet, one tab per band of the
      customer's brew-quiz answer "cups per month" (0-35, 35-65, 65-100, 100-120, 120+). Every column is text except
      is_outlier, as a sheet-backed table is.

Every order_id is a real RAW.SHOPIFY."ORDER".id (as text). Close to the real thing, not an exact copy.

Deliberate traps (documented in docs/INTELLIGEMS_DATA.md):
  - the export is cumulative: the same test x order appears in every export after it was placed; take the latest;
  - order_value_z_score is recomputed in every export, so is_excluded can flip between exports for one order;
  - some orders sit in two tests at once (the tests overlap for two weeks), and the two tests' latest exports have
    different loaded_at_ts;
  - one test was renamed mid-run, so older exports carry its old name;
  - sheet tabs: bands are inclusive at both ends, so a customer who answered exactly 35 / 65 / 100 / 120 is on two tabs;
    empty rows at the bottom of each tab (all NULL); a few real rows with is_outlier left blank; money as '£12.50'.

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
from zoneinfo import ZoneInfo

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
SHOP = os.path.join(ROOT, "data", "raw", "shopify")
RECH = os.path.join(ROOT, "data", "raw", "recharge")
OUT_IG = os.path.join(ROOT, "data", "raw", "intelligems")
OUT_GS = os.path.join(ROOT, "data", "raw", "google_sheets")
R = random.Random(20261106)
UTC, LDN = timezone.utc, ZoneInfo("Europe/London")


def read(path):
    if not os.path.exists(path):
        raise SystemExit(f"missing {path} - run generate_marketing_data.py and generate_recharge_data.py first")
    with open(path, newline="") as f:
        return list(csv.DictReader(f))


def ts(s):
    return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=UTC)


def iso(dt):
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ")


def uid(*parts):
    """A stable uuid-looking id from the seed and the parts."""
    h = hashlib.sha1(("20261106|" + "|".join(map(str, parts))).encode()).hexdigest()
    return f"{h[:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"


def write(folder, table, rows, cols):
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, f"{table}.csv"), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(cols)
        for r in rows:
            w.writerow(["" if r.get(c) is None else r[c] for c in cols])


orders = sorted(read(os.path.join(SHOP, "order.csv")), key=lambda o: (o["created_at"], o["id"]))
units = defaultdict(int)
for li in read(os.path.join(SHOP, "order_line.csv")):
    units[li["order_id"]] += int(li["quantity"])
sub_type = {}
for ro in read(os.path.join(RECH, "orders.csv")):
    sub_type[str(json.loads(ro["external_order_id"])["ecommerce"])] = ro["type"]
first_order = {}
for o in orders:
    first_order.setdefault(o["customer_id"], o["id"])

# eligible traffic: web checkout, not a Shopify test order
web = [o for o in orders if o["source_name"] == "web" and o["test"] != "true"]


def in_window(o, start, end):
    return start <= ts(o["created_at"]).astimezone(LDN).date() <= end


# --------------------------------------------------------------------------------------- Intelligems order export
TESTS = [
    dict(key="ship", name="Free shipping threshold", start=date(2026, 2, 2), end=date(2026, 3, 29),
         variants=["Control", "Free shipping from £25"]),
    dict(key="price", name="1kg bag price", old_name="1kg price test", renamed=date(2026, 4, 13),
         start=date(2026, 3, 16), end=date(2026, 5, 10), variants=["Control (£24.00)", "£22.50", "£26.00"]),
    dict(key="subsave", name="Subscribe & save discount", start=date(2026, 6, 1), end=date(2026, 7, 26),
         variants=["Control (10% off)", "15% off"]),
]

ig_rows = []
for t in TESTS:
    t["test_id"] = uid("test", t["key"])
    vids = {v: uid("variant", t["key"], v) for v in t["variants"]}
    members = []                                            # (order, variant) in placement order
    for o in web:
        if in_window(o, t["start"], t["end"]) and R.random() < 0.75:
            members.append((o, R.choice(t["variants"])))
    # weekly exports on Mondays from the first Monday after the start, the last one a week after the end
    d = t["start"] + timedelta(days=7 - t["start"].weekday())
    exports = []
    while d <= t["end"] + timedelta(days=7):
        exports.append(datetime(d.year, d.month, d.day, 6, R.randint(0, 40), R.randint(0, 59), tzinfo=UTC))
        d += timedelta(days=7)
    for ex in exports:
        sofar = [(o, v) for o, v in members if ts(o["created_at"]) < ex]
        if not sofar:
            continue
        vals = [float(o["total_price"]) for o, _ in sofar]
        mu, sd = statistics.mean(vals), statistics.pstdev(vals) or 1.0
        name = t["old_name"] if t.get("renamed") and ex.date() < t["renamed"] else t["name"]
        for o, v in sofar:
            z = (float(o["total_price"]) - mu) / sd
            ig_rows.append(dict(ig_id=uid("row", t["key"], o["id"], iso(ex)), order_id=o["id"], test_id=t["test_id"],
                                test_name=name, variant_id=vids[v], variant_name=v,
                                is_excluded="true" if abs(z) > 3 else "false",
                                order_value_z_score=f"{z:.6f}", loaded_at_ts=iso(ex)))

ig_rows.sort(key=lambda r: (r["loaded_at_ts"], r["test_id"], r["order_id"]))
write(OUT_IG, "intelligems_data_import_raw", ig_rows,
      ["ig_id", "order_id", "test_id", "test_name", "variant_id", "variant_name", "is_excluded",
       "order_value_z_score", "loaded_at_ts"])

# --------------------------------------------------------------------------------- the sheet: one test, five tabs
SHEET_START, SHEET_END = date(2026, 8, 3), date(2026, 9, 27)
BANDS = [("0_35", 0, 35), ("35_65", 35, 65), ("65_100", 65, 100), ("100_120", 100, 120), ("120_plus", 120, 10 ** 6)]
COLS = ["variation_name", "order_id", "order_name", "customer_id", "order_created_time", "shipping_method",
        "test_order", "total_units", "total_test_units", "product_list_price", "product_discount",
        "intelligems_price_test_discount", "net_product_revenue", "net_shipping_revenue", "net_revenue", "total_tax",
        "net_revenue_incl_tax_and_tip", "product_cogs", "shipping_cost", "transaction_fee", "gross_profit",
        "order_value_z_score", "is_outlier", "subscription_order_type", "new_vs_returning_visitor", "device_type",
        "channel", "timezone", "label"]


def gbp(x):
    return f"£{x:,.2f}"


def channel(o):
    s = (o["landing_site"] or "") + " " + (o["referring_site"] or "")
    if "utm_medium=cpc" in s:
        return "Paid Search"
    if "utm_source=facebook" in s or "utm_source=instagram" in s or "utm_medium=paid_social" in s:
        return "Paid Social"
    if "utm_medium=email" in s or "klaviyo" in s:
        return "Email"
    if "google." in s or "bing." in s:
        return "Organic Search"
    return "Direct"


members = [o for o in web if in_window(o, SHEET_START, SHEET_END) and R.random() < 0.8]
QUIZ = random.Random(20261107)                                # the quiz answer belongs to the customer, not the order
cups = {}
for cid in sorted({o["customer_id"] for o in members}):
    cups[cid] = max(4, min(220, round(QUIZ.lognormvariate(3.8, 0.6))))
vals = [float(o["total_line_items_price"]) for o in members]
mu, sd = statistics.mean(vals), statistics.pstdev(vals)
tabs = {b: [] for b, _, _ in BANDS}
for o in members:
    lp, disc, ship = float(o["total_line_items_price"]), float(o["total_discounts"]), float(o["shipping_price"])
    tax, total = float(o["total_tax"]), float(o["total_price"])
    net_prod = lp - disc
    cogs = round(lp * R.uniform(0.31, 0.37), 2)
    ship_cost = 3.10 if ship > 0 or net_prod >= 30 else 0.0
    fee = round(total * 0.015 + 0.20, 2)
    z = (lp - mu) / sd
    st = sub_type.get(o["id"])
    row = dict(
        variation_name=R.choice(["Control", "Fewer sizes when out of stock"]), order_id=o["id"], order_name=o["name"],
        customer_id=o["customer_id"],
        order_created_time=ts(o["created_at"]).astimezone(LDN).strftime("%Y-%m-%d %H:%M:%S"),
        shipping_method="Free UK delivery" if ship == 0 else "Royal Mail Tracked 48",
        test_order="TRUE", total_units=str(units[o["id"]]), total_test_units=str(units[o["id"]]),
        product_list_price=gbp(lp), product_discount=gbp(disc), intelligems_price_test_discount=gbp(0),
        net_product_revenue=gbp(net_prod), net_shipping_revenue=gbp(ship), net_revenue=gbp(net_prod + ship),
        total_tax=gbp(tax), net_revenue_incl_tax_and_tip=gbp(total), product_cogs=gbp(cogs),
        shipping_cost=gbp(ship_cost), transaction_fee=gbp(fee), gross_profit=gbp(net_prod + ship - cogs - ship_cost - fee),
        order_value_z_score=f"{z:.4f}", is_outlier="TRUE" if abs(z) > 3 else "FALSE",
        subscription_order_type={"CHECKOUT": "Subscription - First", "RECURRING": "Subscription - Recurring"}.get(st, "One-time"),
        new_vs_returning_visitor="New" if first_order[o["customer_id"]] == o["id"] else "Returning",
        device_type=R.choices(["Mobile", "Desktop", "Tablet"], [62, 31, 7])[0], channel=channel(o),
        timezone="Europe/London", label=None)
    for b, lo, hi in BANDS:                                  # inclusive at both ends: a boundary answer is on two tabs
        if lo <= cups[o["customer_id"]] <= hi:
            tabs[b].append(dict(row))

for b, _, _ in BANDS:
    rows = tabs[b]
    for r in R.sample(rows, 2 if len(rows) > 60 else 1):     # someone cleared the cell
        r["is_outlier"] = None
    rows += [{} for _ in range(R.randint(2, 4))]             # empty formatted rows the sheet range picks up
    write(OUT_GS, f"ig_out_of_stock_{b}_orders_table", rows, COLS)

print(f"intelligems_data_import_raw: {len(ig_rows)} rows, {len({r['order_id'] for r in ig_rows})} orders")
for b, _, _ in BANDS:
    print(f"ig_out_of_stock_{b}_orders_table: {len(tabs[b])} rows")
