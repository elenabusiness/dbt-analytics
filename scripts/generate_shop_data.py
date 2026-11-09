"""Generate a small, realistic direct-to-consumer shop dataset as CSV files in data/raw/.

Fictional brand, synthetic people. Deterministic (fixed seed), so everyone gets the same numbers and
the exercise answers can be checked.

It deliberately contains the mess real sources have, because the exercises are about handling it:
  * orders arrive in two files (batch 1, then batch 2); batch 2 re-sends ~8% of batch 1's orders with a
    newer updated_at (refunds, cancellations, fulfilments)  -> dedupe / incremental / merge
  * emails with stray capitals and spaces, and a few customers who registered twice with the same email
  * a handful of order lines with a NULL price, and orders whose header total disagrees with their lines
  * timestamps as ISO strings in UTC ('...Z'); ad spend is daily and keyed by date + channel + campaign
  * subscriptions that start, pause and cancel; some customers have several

Run:  python scripts/generate_shop_data.py      (needs only the standard library)
"""
import csv
import datetime as dt
import os
import random

random.seed(20261104)
OUT = os.path.join(os.path.dirname(__file__), "..", "data", "raw")
os.makedirs(OUT, exist_ok=True)

START = dt.datetime(2024, 1, 1)
END = dt.datetime(2026, 10, 31)
SPAN = (END - START).total_seconds()

FIRST = ["Amelia", "Oliver", "Isla", "George", "Ava", "Noah", "Mia", "Arthur", "Grace", "Leo", "Freya", "Oscar",
         "Lily", "Harry", "Ella", "Jack", "Emily", "Charlie", "Sophie", "Thomas", "Poppy", "James", "Chloe", "Henry"]
LAST = ["Smith", "Jones", "Taylor", "Brown", "Wilson", "Evans", "Thomas", "Roberts", "Walker", "Wright",
        "Hughes", "Green", "Hall", "Wood", "Clarke", "Jackson", "Turner", "Hill", "Moore", "Cooper"]
COUNTRIES = ["GB"] * 14 + ["IE", "DE", "FR", "NL", "US"]
DOMAINS = ["gmail.com", "outlook.com", "yahoo.co.uk", "icloud.com", "hotmail.co.uk"]

PRODUCTS = [
    # id, sku, title, type, price, subscribable
    (101, "JNT-60", "Joint Support Chews 60", "supplement", 29.99, True),
    (102, "JNT-120", "Joint Support Chews 120", "supplement", 49.99, True),
    (103, "SKN-60", "Skin & Coat Chews 60", "supplement", 27.99, True),
    (104, "DIG-60", "Digestion Chews 60", "supplement", 26.99, True),
    (105, "CLM-60", "Calming Chews 60", "supplement", 28.99, True),
    (106, "DNT-30", "Dental Sticks 30", "treat", 14.99, True),
    (107, "TRT-MIX", "Training Treats Mix", "treat", 9.99, False),
    (108, "BWL-STL", "Steel Bowl", "accessory", 19.99, False),
    (109, "LSH-RED", "Rope Lead Red", "accessory", 24.99, False),
    (110, "GFT-BOX", "Gift Box", "bundle", 59.99, False),
]
CHANNELS = {"meta": ["prospecting_uk", "retargeting_uk", "lookalike_eu"],
            "google": ["brand_search", "generic_search", "pmax_shopping"],
            "tiktok": ["spark_ads_uk"]}
SOURCES = ["web"] * 8 + ["subscription_contract"] * 3 + ["shop_app", "draft_order"]
CODES = [None] * 10 + ["WELCOME10", "SPRING15", "BFCM25", "VIP20"]


def ts(d):
    return d.strftime("%Y-%m-%dT%H:%M:%SZ")


def rand_time(lo=START, hi=END):
    return lo + dt.timedelta(seconds=random.random() * (hi - lo).total_seconds())


def write(name, header, rows):
    with open(os.path.join(OUT, name), "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(header)
        w.writerows(rows)
    print(f"{name:28s} {len(rows):6d} rows")


# products
write("products.csv", ["id", "sku", "title", "product_type", "price", "is_subscribable"],
      [(p[0], p[1], p[2], p[3], f"{p[4]:.2f}", str(p[5]).lower()) for p in PRODUCTS])

# customers (~4% re-register with the same email, differently cased)
customers = []
cid = 5000
for i in range(2400):
    cid += 1
    fn, ln = random.choice(FIRST), random.choice(LAST)
    email = f"{fn}.{ln}{random.randint(1, 999)}@{random.choice(DOMAINS)}".lower()
    created = rand_time()
    customers.append([cid, email, fn, ln, random.choice(COUNTRIES), ts(created),
                      ts(created + dt.timedelta(days=random.randint(0, 200))) if random.random() < .3 else ts(created),
                      str(random.random() < .55).lower()])
for c in random.sample(customers, 96):
    cid += 1
    created = dt.datetime.strptime(c[5], "%Y-%m-%dT%H:%M:%SZ") + dt.timedelta(days=random.randint(5, 300))
    created = min(created, END)
    messy = (" " if random.random() < .5 else "") + c[1].capitalize() + (" " if random.random() < .5 else "")
    customers.append([cid, messy, c[2], c[3], c[4], ts(created), ts(created), "false"])
for c in random.sample(customers, 40):  # stray capitals/spaces on some originals too
    c[1] = " " + c[1].upper() if random.random() < .5 else c[1].title()
write("customers.csv", ["id", "email", "first_name", "last_name", "country", "created_at", "updated_at",
                        "accepts_marketing"], customers)

# subscriptions
subs, sid = [], 70000
for c in random.sample(customers, 700):
    for _ in range(1 if random.random() < .85 else 2):
        sid += 1
        p = random.choice([p for p in PRODUCTS if p[5]])
        created = max(rand_time(), dt.datetime.strptime(c[5], "%Y-%m-%dT%H:%M:%SZ"))
        r = random.random()
        status, cancelled = ("active", None) if r < .45 else ("paused", None) if r < .55 else (
            "cancelled", created + dt.timedelta(days=random.randint(20, 400)))
        if cancelled and cancelled > END:
            status, cancelled = "active", None
        subs.append([sid, c[0], p[0], status, ts(created), ts(cancelled) if cancelled else "",
                     random.choice([30, 30, 30, 60, 90])])
write("subscriptions.csv", ["id", "customer_id", "product_id", "status", "created_at", "cancelled_at",
                            "interval_days"], subs)

# orders + lines; a customer's orders cluster after their signup; subscribers reorder on their interval
orders, lines = [], []
oid, lid = 1_000_000, 9_000_000
by_cust = {c[0]: dt.datetime.strptime(c[5], "%Y-%m-%dT%H:%M:%SZ") for c in customers}
sub_by_cust = {}
for s in subs:
    sub_by_cust.setdefault(s[1], []).append(s)

def add_order(cust, when, source, items):
    global oid, lid
    oid += 1
    code = random.choice(CODES)
    disc_rate = {"WELCOME10": .10, "SPRING15": .15, "BFCM25": .25, "VIP20": .20}.get(code, 0)
    subtotal = 0.0
    for prod, qty in items:
        lid += 1
        price = prod[4]
        line_disc = round(price * qty * disc_rate, 2)
        subtotal += price * qty - line_disc
        lines.append([lid, oid, prod[0], qty, "" if random.random() < .004 else f"{price:.2f}", f"{line_disc:.2f}"])
    shipping = 0 if subtotal >= 35 else 3.95
    total = round(subtotal + shipping, 2)
    if random.random() < .01:          # header total that disagrees with its lines
        total = round(total + random.choice([-5, 5, 10]), 2)
    fin = random.choices(["paid", "refunded", "partially_refunded", "pending"], [92, 4, 2, 2])[0]
    fulf = "fulfilled" if fin != "pending" else None
    orders.append([oid, cust, ts(when), ts(when + dt.timedelta(hours=random.randint(1, 72))), fin, fulf or "",
                   "GBP", f"{total:.2f}", code or "", source, ""])

for c in customers:
    first = by_cust[c[0]] + dt.timedelta(hours=random.randint(0, 48))
    n = random.choices([0, 1, 2, 3, 4, 6, 9], [10, 38, 20, 12, 9, 7, 4])[0]
    when = first
    for k in range(n):
        if when > END:
            break
        items = [(random.choice(PRODUCTS), random.choice([1, 1, 1, 2])) for _ in range(random.choice([1, 1, 2, 3]))]
        add_order(c[0], when, random.choice(SOURCES), items)
        when += dt.timedelta(days=random.randint(10, 160))
    for s in sub_by_cust.get(c[0], []):
        start = dt.datetime.strptime(s[4], "%Y-%m-%dT%H:%M:%SZ")
        stop = dt.datetime.strptime(s[5], "%Y-%m-%dT%H:%M:%SZ") if s[5] else END
        when = start
        prod = next(p for p in PRODUCTS if p[0] == s[2])
        while when <= stop:
            add_order(c[0], when, "subscription_contract", [(prod, 1)])
            when += dt.timedelta(days=s[6] + random.randint(-2, 3))

orders.sort(key=lambda o: o[2])
lines_by_order = {}
for ln in lines:
    lines_by_order.setdefault(ln[1], []).append(ln)

cut = ts(dt.datetime(2026, 7, 1))
batch1 = [o for o in orders if o[2] < cut]
batch2 = [o for o in orders if o[2] >= cut]
# batch 2 re-sends some older orders with a later state
resent = []
for o in random.sample(batch1, int(len(batch1) * .08)):
    o2 = list(o)
    o2[3] = ts(rand_time(dt.datetime(2026, 7, 1), END))
    o2[4] = random.choice(["refunded", "partially_refunded", "paid"])
    if random.random() < .25:
        o2[10] = o2[3]  # cancelled_at
        o2[4] = "voided"
        o2[5] = ""
    resent.append(o2)
OH = ["id", "customer_id", "created_at", "updated_at", "financial_status", "fulfillment_status", "currency",
      "total_price", "discount_code", "source_name", "cancelled_at"]
write("orders_batch_1.csv", OH, batch1)
write("orders_batch_2.csv", OH, batch2 + resent)
LH = ["id", "order_id", "product_id", "quantity", "price", "discount"]
b1 = {o[0] for o in batch1}
write("order_lines_batch_1.csv", LH, [ln for ln in lines if ln[1] in b1])
write("order_lines_batch_2.csv", LH, [ln for ln in lines if ln[1] not in b1])

# ad spend: daily rows per channel/campaign; spend grows over time, spikes in late November
spend = []
d = START.date()
while d <= END.date():
    for ch, camps in CHANNELS.items():
        for camp in camps:
            if ch == "tiktok" and d < dt.date(2025, 3, 1):
                continue
            base = {"meta": 140, "google": 90, "tiktok": 60}[ch] * (1 + (d - START.date()).days / 900)
            if d.month == 11 and d.day >= 20:
                base *= 2.4
            s = round(base * random.uniform(.6, 1.4) / len(camps), 2)
            imps = int(s * random.uniform(80, 140))
            spend.append([d.isoformat(), ch, camp, f"{s:.2f}", imps, int(imps * random.uniform(.008, .03))])
    d += dt.timedelta(days=1)
write("ad_spend.csv", ["date", "channel", "campaign", "spend", "impressions", "clicks"], spend)
