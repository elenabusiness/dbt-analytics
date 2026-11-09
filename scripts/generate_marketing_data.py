"""Generate a year of made-up Shopify + Meta Ads data for a fictional UK coffee brand, Fernhill Coffee.

The tables are modelled on how ELT connectors (Fivetran's Shopify and Facebook Ads connectors) land these two
sources in a warehouse: one table per API object, *_HISTORY tables that keep every version of a campaign / ad
set / ad, JSON (VARIANT) columns, `_fivetran_synced` / `_fivetran_deleted`. Close to the real thing, not a
byte-for-byte copy of either connector.

The two sources are linked the way they are in real life: Meta ads drive clicks, some clicks become Shopify
orders, and those orders carry the ad's UTM parameters in `landing_site`. Meta also reports its own purchase
counts, which do not match Shopify's. Working out why is most of the practice.

Deterministic (fixed seed): every run writes the same files, so the numbers in docs/ANSWERS.md hold.

Run:  python scripts/generate_marketing_data.py     -> data/raw/shopify/*.csv, data/raw/meta_ads/*.csv
Then: python scripts/load_marketing.py              -> RAW.SHOPIFY, RAW.META_ADS
"""
import csv
import json
import math
import os
import random
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from urllib.parse import quote
from zoneinfo import ZoneInfo

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "data", "raw")
R = random.Random(20261104)
LON, LA, UTC = ZoneInfo("Europe/London"), ZoneInfo("America/Los_Angeles"), timezone.utc
START, END = date(2025, 11, 1), date(2026, 10, 31)          # Meta account days (Los Angeles time)
SYNCED = datetime(2026, 11, 1, 6, 12, 41, tzinfo=UTC)        # the connector's last sync
SHOP_ID, ACCOUNT_ID = 61234567890, 1029384756473829


def iso(dt):
    return dt.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def synced():
    return iso(SYNCED - timedelta(minutes=R.randint(0, 600)))


def poisson(lam):
    if lam <= 0:
        return 0
    if lam > 30:
        return max(0, int(R.gauss(lam, math.sqrt(lam)) + 0.5))
    limit, k, p = math.exp(-lam), 0, 1.0
    while True:
        p *= R.random()
        if p <= limit:
            return k
        k += 1


def write(schema, table, rows, cols):
    os.makedirs(os.path.join(OUT, schema), exist_ok=True)
    with open(os.path.join(OUT, schema, f"{table}.csv"), "w", newline="") as f:
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
    print(f"{schema}/{table}.csv".ljust(40), f"{len(rows):>7d} rows")


_ids = {}


def nid(kind, start):
    _ids[kind] = _ids.get(kind, start) + R.randint(1, 9)
    return _ids[kind]


# ─────────────────────────── Shopify catalogue ───────────────────────────
# (title, product_type, VAT %, variants [(title, sku, price before the March 2026 rise)], status, created)
CATALOGUE = [
    ("Huila Washed - Colombia", "Coffee", 0, [("250g", "HUI-250", 9.50), ("1kg", "HUI-1K", 32.00)], "active", "2024-03-01"),
    ("Yirgacheffe Kochere - Ethiopia", "Coffee", 0, [("250g", "YIR-250", 11.00), ("1kg", "YIR-1K", 38.00)], "active", "2024-03-01"),
    ("Santa Ana Washed - El Salvador", "Coffee", 0, [("250g", "SAN-250", 10.00), ("1kg", "SAN-1K", 34.00)], "active", "2024-06-12"),
    ("Kiambu AA - Kenya", "Coffee", 0, [("250g", "KIA-250", 12.50)], "active", "2025-01-20"),
    ("House Espresso Blend", "Coffee", 0, [("250g", "ESP-250", 8.50), ("1kg", "ESP-1K", 28.00)], "active", "2024-03-01"),
    ("Decaf - Sugar Cane Process", "Coffee", 0, [("250g", "DEC-250", 9.50)], "active", "2024-09-01"),
    ("Christmas Blend 2025", "Coffee", 0, [("250g", "XMS25-250", 10.50)], "archived", "2025-11-01"),
    ("Burr Grinder One", "Equipment", 20, [("Black", "GRD1-BLK", 149.00), ("White", "GRD1-WHT", 149.00)], "active", "2026-05-01"),
    ("V60 Dripper", "Equipment", 20, [("Ceramic", "V60-CER", 24.00), ("Plastic", "V60-PLA", 9.00)], "active", "2024-03-01"),
    ("Brew Scale", "Equipment", 20, [("Default Title", "SCALE-01", 35.00)], "active", "2024-03-01"),
    ("Gooseneck Kettle", "Equipment", 20, [("Default Title", "KET-01", 59.00)], "active", "2024-11-01"),
    ("Paper Filters (100)", "Equipment", 20, [("Size 02", "FIL-02", 6.00)], "active", "2024-03-01"),
    ("Fernhill Gift Card", "Gift Card", None, [("£25", "GIFT-25", 25.00), ("£50", "GIFT-50", 50.00)], "active", "2024-11-15"),
    ("Tasting Flight Box", "Coffee", 0, [("4 x 100g", "FLIGHT-4", 22.00)], "draft", "2026-09-20"),
]
products, variants = [], []
for title, ptype, vat, vs, status, created in CATALOGUE:
    pid = nid("product", 7_400_000_000_000)
    c = datetime.fromisoformat(created).replace(hour=10, tzinfo=LON)
    handle = "".join(ch for ch in title.lower().replace(" - ", "-").replace(" ", "-") if ch.isalnum() or ch == "-")
    products.append(dict(id=pid, title=title, handle=handle, product_type=ptype, vendor="Fernhill Coffee", status=status,
                         tags="coffee,single-origin" if ptype == "Coffee" and "Blend" not in title and "Decaf" not in title else ptype.lower(),
                         created_at=iso(c), updated_at=iso(c + timedelta(days=R.randint(5, 400))) if status != "draft" else iso(c),
                         published_at=iso(c) if status == "active" else None, _fivetran_synced=synced(), _fivetran_deleted=False))
    for vt, sku, price in vs:
        current = round(price * 1.08, 1) if ptype == "Coffee" and status == "active" else price   # beans went up on 1 Mar 2026
        variants.append(dict(id=nid("variant", 44_100_000_000_000), product_id=pid, title=vt, sku=sku, price=float(current),
                             compare_at_price=None, inventory_quantity=R.randint(0, 400), created_at=iso(c),
                             updated_at=iso(max(c + timedelta(days=R.randint(5, 600)), datetime(2026, 3, 1, 9, tzinfo=UTC))),
                             _fivetran_synced=synced(),
                             _p=dict(ptype=ptype, vat=vat, title=title, start=c.date(), status=status, old_price=price)))


def sellable(d):
    out = []
    for v in variants:
        m = v["_p"]
        if m["status"] == "draft" or d < m["start"]:
            continue
        if m["title"].startswith("Christmas Blend") and not (date(2025, 11, 1) <= d <= date(2026, 1, 6)):
            continue
        if m["ptype"] == "Gift Card" and not (date(2025, 11, 15) <= d <= date(2025, 12, 24)):
            continue
        out.append(v)
    return out


def WEIGHT(v):                                       # how often a variant ends up in a basket: mostly beans
    sku, t = v["sku"], v["_p"]["ptype"]
    return (0.25 if sku.startswith("GRD") else 4 if sku.startswith("FIL") else 1.2 if t == "Equipment"
            else 3 if t == "Gift Card" else 4 if sku.endswith("1K") else 10)


def price_on(v, d):
    return v["price"] if d >= date(2026, 3, 1) else v["_p"]["old_price"]   # the variant table only keeps today's price


# ─────────────────────────── Meta Ads structure ───────────────────────────
# (name, objective, start, end, daily budget £, renames [(date, new name)], kind)
CAMPAIGNS = [
    ("Prospecting | Broad | Sales", "OUTCOME_SALES", "2025-11-01", None, 60, [("2026-03-02", "PROS | Broad | Advantage+")], "pros"),
    ("Retargeting | 30d visitors", "OUTCOME_SALES", "2025-11-01", None, 25, [], "retarget"),
    ("Black Friday 2025", "OUTCOME_SALES", "2025-11-21", "2025-12-01", 180, [], "promo"),
    ("Christmas Gifting 2025", "OUTCOME_SALES", "2025-12-03", "2025-12-20", 120, [], "promo"),
    ("Brand Awareness | Video", "OUTCOME_AWARENESS", "2026-02-02", "2026-04-26", 35, [], "awareness"),
    ("Grinder Launch", "OUTCOME_SALES", "2026-05-11", "2026-06-30", 90, [], "launch"),
    ("Traffic | Brew Guides", "OUTCOME_TRAFFIC", "2026-07-06", None, 20, [], "traffic"),
    ("Prospecting | Lookalike 1%", "OUTCOME_SALES", "2026-09-01", "2026-10-15", 50, [], "pros"),
]
BUDGET_CHANGES = {7: [("2026-09-15", 80), ("2026-10-01", 120)]}       # the lookalike test, scaled twice then paused
KIND = dict(pros=(0.011, 0.020), retarget=(0.016, 0.045), promo=(0.015, 0.032), awareness=(0.004, 0.001),
            launch=(0.013, 0.012), traffic=(0.021, 0.002))             # (click-through rate, click -> order rate)
VIEW_RATE = dict(pros=0.00012, retarget=0.0006, promo=0.0003, awareness=0.00004, launch=0.00008, traffic=0.00002)
TEMPLATE = "utm_source=facebook&utm_medium=paid_social&utm_campaign={{campaign.name}}&utm_content={{ad.id}}"


def budget_on(ci, d):
    b = CAMPAIGNS[ci][4]
    for when, new in BUDGET_CHANGES.get(ci, []):
        if d >= date.fromisoformat(when):
            b = new
    return b


def la_dt(d, h=9):
    return datetime.combine(d, time(h, R.randint(0, 59)), LA)


account_rows = [dict(id=ACCOUNT_ID, name="Fernhill Coffee - Ads", account_status=1, currency="GBP", timezone_name="America/Los_Angeles",
                     business_country_code="GB", created_time=iso(datetime(2024, 2, 20, 9, tzinfo=UTC)),
                     updated_time=iso(datetime(2025, 10, 1, 9, tzinfo=UTC)), _fivetran_synced=synced())]
campaign_rows, adset_rows, ad_rows, creative_rows, ads = [], [], [], [], []

for ci, (name, objective, s, e, budget, renames, kind) in enumerate(CAMPAIGNS):
    cid = 120_200_000_000_000_000 + ci * 1_000_003 + R.randint(0, 999)
    s, e = date.fromisoformat(s), (date.fromisoformat(e) if e else None)
    cbo = kind in ("pros", "promo", "launch")      # budget on the campaign (CBO) or on its single ad set
    versions = [(la_dt(s - timedelta(days=2)), dict(name=name, status="ACTIVE", daily_budget=budget * 100 if cbo else None))]
    for rd, new in renames:
        versions.append((la_dt(date.fromisoformat(rd), 11), dict(versions[-1][1], name=new)))
    for when, new in BUDGET_CHANGES.get(ci, []):
        versions.append((la_dt(date.fromisoformat(when), 8), dict(versions[-1][1], daily_budget=new * 100)))
    if e:
        versions.append((la_dt(e + timedelta(days=1), 8), dict(versions[-1][1], status="ARCHIVED" if e < date(2026, 7, 1) else "PAUSED")))
    for vt, v in versions:
        campaign_rows.append(dict(id=cid, account_id=ACCOUNT_ID, name=v["name"], objective=objective, status=v["status"],
                                  daily_budget=v["daily_budget"], lifetime_budget=None, buying_type="AUCTION",
                                  start_time=iso(la_dt(s, 0)), stop_time=iso(la_dt(e, 23)) if e else None,
                                  created_time=iso(versions[0][0]), updated_time=iso(vt), _fivetran_synced=synced()))
    n_sets = {"pros": 2, "retarget": 1, "promo": 2, "awareness": 1, "launch": 2, "traffic": 1}[kind]
    for si in range(n_sets):
        sid = cid + 10_000 * (si + 1)
        aud = ["Broad UK 25-55", "Interest: specialty coffee", "Website visitors 30d", "Lookalike 1% purchasers"][
            2 if kind == "retarget" else 3 if ci == 7 else si % 2]
        sname = f"{aud} | {['Feed', 'Reels'][si % 2]}"
        targeting = {"age_min": 25, "age_max": 55 if "Broad" in aud else 65,
                     "geo_locations": {"countries": ["GB"] + (["IE"] if kind == "promo" else [])},
                     "publisher_platforms": ["facebook", "instagram"]}
        if kind == "retarget":
            targeting["custom_audiences"] = [{"id": "23851234567890123", "name": "Website visitors 30d"}]
        if ci == 7:
            targeting["custom_audiences"] = [{"id": "23851234567890999", "name": "Lookalike (GB, 1%) - Purchasers 180d"}]
        goal = {"OUTCOME_SALES": "OFFSITE_CONVERSIONS", "OUTCOME_TRAFFIC": "LANDING_PAGE_VIEWS", "OUTCOME_AWARENESS": "THRUPLAY"}[objective]
        set_versions = [(la_dt(s - timedelta(days=2), 10), "ACTIVE")] + ([(la_dt(e + timedelta(days=1), 8), "PAUSED")] if e else [])
        for vt, st in set_versions:
            adset_rows.append(dict(id=sid, campaign_id=cid, account_id=ACCOUNT_ID, name=sname, status=st,
                                   daily_budget=None if cbo else budget * 100, optimization_goal=goal, billing_event="IMPRESSIONS",
                                   bid_strategy="LOWEST_COST_WITHOUT_CAP", targeting=targeting, start_time=iso(la_dt(s, 0)),
                                   end_time=iso(la_dt(e, 23)) if e else None, created_time=iso(set_versions[0][0]),
                                   updated_time=iso(vt), _fivetran_synced=synced()))
        n_ads = 3 if kind in ("pros", "launch") else 2
        for ai in range(n_ads):
            aid = sid + 100 * (ai + 1) + R.randint(0, 49)
            crid = aid + 50
            fmt = ["Video", "Static", "Carousel"][ai % 3]
            ad_name = f"{fmt} | {['Origin story', 'Brew at home', 'Fresh roast date', 'Gift idea', 'Grinder demo'][(ci + ai) % 5]} | v{ai + 1}"
            url_tags = TEMPLATE
            if ci == 2 and ai == 1:
                url_tags = "utm_source=fb&utm_medium=cpc&utm_campaign=bf2025"          # typed by hand in a hurry
            if ci == 1 and ai == 1:
                url_tags = None                                                       # UTMs forgotten entirely
            creative_rows.append(dict(id=crid, account_id=ACCOUNT_ID, name=f"{ad_name} - creative",
                                      title=["Freshly roasted, every week", "Better coffee at home"][ai % 2],
                                      body="Roasted to order in small batches. Free UK delivery over £30.", call_to_action_type="SHOP_NOW",
                                      object_type="VIDEO" if fmt == "Video" else "SHARE", link_url="https://fernhillcoffee.example/",
                                      url_tags=url_tags, _fivetran_synced=synced()))
            a_end = date(2026, 1, 31) if (kind == "pros" and ai == 2 and e is None) else e    # creative fatigue: paused
            ad_versions = [(la_dt(s - timedelta(days=1), 12), "ACTIVE")] + ([(la_dt(a_end + timedelta(days=1), 7), "PAUSED")] if a_end else [])
            for vt, st in ad_versions:
                ad_rows.append(dict(id=aid, ad_set_id=sid, campaign_id=cid, account_id=ACCOUNT_ID, name=ad_name, status=st,
                                    creative_id=crid, created_time=iso(ad_versions[0][0]), updated_time=iso(vt), _fivetran_synced=synced()))
            ads.append(dict(id=aid, set_id=sid, ci=ci, kind=kind, start=s, end=a_end or END, url_tags=url_tags,
                            name=ad_name, set_name=sname, renames=renames, cname=name))


def campaign_name_on(ad, d):
    nm = ad["cname"]
    for rd, new in ad["renames"]:
        if d >= date.fromisoformat(rd):
            nm = new
    return nm


def season(d):
    m = 1.0
    if date(2025, 11, 21) <= d <= date(2025, 12, 1):
        m = 2.4
    elif date(2025, 12, 2) <= d <= date(2025, 12, 20):
        m = 1.7
    elif date(2025, 12, 24) <= d <= date(2025, 12, 27):
        m = 0.35
    elif d.month == 1:
        m = 1.15                       # new-year resolutions: brewing at home
    elif d.month in (7, 8):
        m = 0.8
    return m * (1.12 if d.weekday() in (6, 0) else 1.0)


# ─────────────────────────── daily ad delivery, and the orders it drives ───────────────────────────
basic_ad, actions, action_values, ad_orders = [], [], [], []
d = START
while d <= END:
    live = [a for a in ads if a["start"] <= d <= a["end"]]
    per_campaign = defaultdict(int)
    for a in live:
        per_campaign[a["ci"]] += 1
    for ad in live:
        ctr, cvr = KIND[ad["kind"]]
        spend = round(budget_on(ad["ci"], d) / per_campaign[ad["ci"]] * R.uniform(0.78, 1.18) * (1.12 if season(d) > 1.5 else 1), 2)
        cpm = R.uniform(6, 11) * (1.35 if d.month in (11, 12) else 1)
        impressions = int(spend / cpm * 1000)
        freq = R.uniform(1.8, 3.2) if ad["kind"] == "retarget" else R.uniform(1.1, 1.6)
        reach = int(impressions / freq)
        clicks = max(0, int(round(impressions * ctr * R.uniform(0.8, 1.2))))
        lpv = int(clicks * R.uniform(0.72, 0.88))
        click_orders = poisson(clicks * cvr * season(d) ** 0.5)
        view_orders = poisson(reach * VIEW_RATE[ad["kind"]])
        meta_click = 0
        for _ in range(click_orders):
            lag = 0 if R.random() < 0.68 else R.choice([1, 1, 2, 3, 4, 6])
            t = la_dt(d, R.randint(6, 22)) + timedelta(days=lag, minutes=R.randint(3, 50))
            ad_orders.append((t.astimezone(UTC), ad, d, lag == 0 or R.random() < 0.45))
            if R.random() < 0.93:          # the pixel misses a few (ad blockers, iOS)
                meta_click += 1
        fid = f"{ad['id']}{d.strftime('%Y%m%d')}"
        basic_ad.append(dict(_fivetran_id=fid, ad_id=ad["id"], date=d.isoformat(), account_id=ACCOUNT_ID, ad_name=ad["name"],
                             adset_name=ad["set_name"], impressions=impressions, inline_link_clicks=clicks, reach=reach,
                             frequency=round(impressions / reach, 6) if reach else None, spend=spend,
                             cpc=round(spend / clicks, 6) if clicks else None,
                             cpm=round(spend / impressions * 1000, 6) if impressions else None,
                             ctr=round(clicks / impressions * 100, 6) if impressions else None, _fivetran_synced=synced()))
        atc = int(clicks * R.uniform(0.06, 0.12) * (2 if ad["kind"] == "retarget" else 1))
        ic = int(atc * R.uniform(0.45, 0.7))
        acts = [("link_click", clicks, clicks, 0), ("landing_page_view", lpv, lpv, 0), ("add_to_cart", atc, atc, 0),
                ("initiate_checkout", ic, ic, 0)]
        p_total = meta_click + view_orders
        acts += [(at, p_total, meta_click, view_orders) for at in ("purchase", "offsite_conversion.fb_pixel_purchase", "omni_purchase")]
        for i, (at, v, c7, v1) in enumerate(a for a in acts if a[1]):
            actions.append(dict(_fivetran_id=fid, ad_id=ad["id"], date=d.isoformat(), index=i, action_type=at, value=v,
                                _7_d_click=c7, _1_d_view=v1 or None, _fivetran_synced=synced()))
        if p_total:
            avg = R.uniform(95, 140) if ad["kind"] == "launch" else R.uniform(28, 42)
            val_c, val_v = round(meta_click * avg, 2), round(view_orders * avg * R.uniform(0.8, 1.1), 2)
            for i, at in enumerate(("purchase", "offsite_conversion.fb_pixel_purchase", "omni_purchase")):
                action_values.append(dict(_fivetran_id=fid, ad_id=ad["id"], date=d.isoformat(), index=i, action_type=at,
                                          value=round(val_c + val_v, 2), _7_d_click=val_c, _1_d_view=val_v or None,
                                          _fivetran_synced=synced()))
    d += timedelta(days=1)

# ─────────────────────────── Shopify customers, orders, refunds, payments ───────────────────────────
FIRST = ("Amelia Oliver Isla George Ava Noah Mia Arthur Ivy Leo Freya Harry Grace Oscar Lily Jack Ella Henry Rosie Theo "
         "Sophie Alfie Evie Charlie Poppy Jacob Chloe Thomas Maya Archie").split()
LAST = ("Smith Jones Taylor Brown Williams Wilson Johnson Davies Patel Wright Robinson Thompson Evans Walker White Roberts "
        "Green Hall Wood Clarke Khan Murphy Kelly Byrne Hughes Edwards").split()
CITIES = [("London", "ENG", "GB", "E8 3RL"), ("Manchester", "ENG", "GB", "M4 1HN"), ("Bristol", "ENG", "GB", "BS1 5TR"),
          ("Leeds", "ENG", "GB", "LS6 2AB"), ("Edinburgh", "SCT", "GB", "EH6 4QS"), ("Cardiff", "WLS", "GB", "CF10 1EP"),
          ("Brighton", "ENG", "GB", "BN1 4GH"), ("Norwich", "ENG", "GB", "NR2 4PD"), ("Belfast", "NIR", "GB", "BT7 1NN"),
          ("Dublin", "D", "IE", "D08 X2A4"), ("Cork", "CO", "IE", "T12 K8AF")]
customers, orders, lines, refunds, refund_lines, transactions = [], [], [], [], [], []
order_no = 1000


def new_customer(t):
    fn, ln = R.choice(FIRST), R.choice(LAST)
    city = R.choice(CITIES[:-2]) if R.random() < 0.93 else R.choice(CITIES[-2:])
    email = f"{fn}.{ln}{R.randint(1, 999)}@{R.choice(['gmail.com', 'outlook.com', 'icloud.com', 'yahoo.co.uk', 'hotmail.co.uk'])}".lower()
    c = dict(id=nid("customer", 6_900_000_000_000), email=email, first_name=fn, last_name=ln,
             phone=None if R.random() < 0.6 else f"+447{R.randint(100000000, 999999999)}", accepts_marketing=R.random() < 0.55,
             state="enabled" if R.random() < 0.7 else "disabled", tags="",
             default_address={"city": city[0], "province_code": city[1], "country_code": city[2], "zip": city[3]},
             created_at=iso(t - timedelta(minutes=R.randint(1, 20))), updated_at=None, orders_count=0, total_spent=0.0,
             _fivetran_synced=synced(), _fivetran_deleted=False, _n=[])
    if R.random() < 0.012 and len(customers) > 50:     # the same person again, new account, email typed with a capital
        old = R.choice(customers)
        c.update(email=old["email"].capitalize(), first_name=old["first_name"], last_name=old["last_name"],
                 default_address=old["default_address"])
    customers.append(c)
    return c


def pick_customer(t):
    r = R.random()
    if r < 0.03:
        return None                                    # guest checkout: no customer record
    if r < 0.40 and customers:
        return R.choice(customers[-2500:])
    return new_customer(t)


def add_refund(o, items, t, shipping, fx, pres_cur, gw):
    """items: [(order line, quantity refunded)]. Shipping goes back on the transaction but has no refund line."""
    rid = nid("refund", 9_200_000_000_000)
    refunds.append(dict(id=rid, order_id=o["id"], created_at=iso(t), processed_at=iso(t),
                        note=R.choice([None, "Damaged in post", "Changed mind", "Wrong grind"]), restock=False, _fivetran_synced=synced()))
    amt = shipping
    for r, q in items:
        sub = round(r["price"] * q - r["total_discount"] * q / r["quantity"], 2)
        vat = r["_vat"] or 0
        refund_lines.append(dict(id=nid("rline", 4_100_000_000_000), refund_id=rid, order_line_id=r["id"], quantity=q, subtotal=sub,
                                 total_tax=round(sub * vat / (100 + vat), 2) if vat else 0.0, restock_type="no_restock",
                                 _fivetran_synced=synced()))
        amt += sub
    transactions.append(dict(id=nid("tx", 7_000_000_000_000), order_id=o["id"], refund_id=rid, kind="refund", status="success",
                             gateway=gw, amount=round(amt * fx, 2), currency=pres_cur, created_at=iso(t), test=o["test"],
                             _fivetran_synced=synced()))
    o["updated_at"] = max(o["updated_at"], iso(t))
    return amt


def make_order(t_utc, landing, referring, source="web"):
    global order_no
    d_lon = t_utc.astimezone(LON).date()
    cust = pick_customer(t_utc)
    pool = sellable(d_lon)
    weights = [WEIGHT(v) for v in pool]
    chosen = []
    for _ in range(R.choices([1, 2, 3, 4], [55, 28, 12, 5])[0]):
        v = R.choices(pool, weights)[0]
        if v not in chosen:
            chosen.append(v)
    if landing and "grinder" in landing.lower():
        g = [v for v in pool if v["sku"].startswith("GRD")]
        if g:
            chosen = [R.choice(g)] + [v for v in chosen if not v["sku"].startswith("GRD")][:1]
    code = None
    if date(2025, 11, 21) <= d_lon <= date(2025, 12, 1) and R.random() < 0.6:
        code = ("BF25", "percentage", 0.25)
    elif cust and cust["orders_count"] == 0 and R.random() < 0.25:
        code = ("WELCOME10", "percentage", 0.10)
    order_no += 1
    oid = nid("order", 5_800_000_000_000)
    rows, subtotal, discount, tax = [], 0.0, 0.0, 0.0
    for v in chosen:
        q = 1 if v["_p"]["ptype"] == "Equipment" else R.choices([1, 2, 3], [78, 17, 5])[0]
        p = price_on(v, d_lon)
        disc = round(p * q * code[2], 2) if code and v["_p"]["ptype"] == "Coffee" else 0.0
        vat = v["_p"]["vat"]
        tax += round((p * q - disc) * vat / (100 + vat), 2) if vat else 0.0
        subtotal += p * q - disc
        discount += disc
        rows.append(dict(id=nid("line", 14_500_000_000_000), order_id=oid, product_id=v["product_id"], variant_id=v["id"], sku=v["sku"],
                         title=v["_p"]["title"], variant_title=v["title"], vendor="Fernhill Coffee", quantity=q, price=p,
                         total_discount=disc, gift_card=v["_p"]["ptype"] == "Gift Card", taxable=bool(vat),
                         requires_shipping=v["_p"]["ptype"] != "Gift Card", fulfillable_quantity=0, _fivetran_synced=synced(), _vat=vat))
    subtotal, discount = round(subtotal, 2), round(discount, 2)
    shipping = 0.0 if source == "pos" or subtotal >= 30 or all(r["gift_card"] for r in rows) else 3.95
    tax = round(tax + (shipping * 20 / 120 if shipping else 0), 2)
    total = round(subtotal + shipping, 2)
    country = cust["default_address"]["country_code"] if cust else "GB"
    pres_cur, fx = ("EUR", 1.17) if country == "IE" else ("USD", 1.27) if R.random() < 0.01 else ("GBP", 1.0)
    is_test = source == "web" and R.random() < 0.003
    fin = R.choices(["paid", "pending", "voided"], [988, 7, 5])[0] if source != "pos" else "paid"
    cancelled = fin == "voided" or R.random() < 0.006
    if cancelled and fin == "pending":
        fin = "voided"
    upd = iso(t_utc + timedelta(hours=R.randint(1, 60)))
    o = dict(id=oid, name=f"#{order_no}", order_number=order_no,
             email=cust["email"] if cust else f"guest{R.randint(1, 99999)}@gmail.com", customer_id=cust["id"] if cust else None,
             created_at=iso(t_utc), processed_at=iso(t_utc), updated_at=upd,
             cancelled_at=iso(t_utc + timedelta(hours=R.randint(2, 30))) if cancelled else None,
             cancel_reason=R.choice(["customer", "inventory", "fraud"]) if cancelled else None,
             closed_at=iso(t_utc + timedelta(days=R.randint(2, 6))) if not cancelled and fin == "paid" else None,
             financial_status="refunded" if cancelled and fin == "paid" else fin,
             fulfillment_status="fulfilled" if fin == "paid" and not cancelled else None,
             currency="GBP", presentment_currency=pres_cur, subtotal_price=subtotal, total_discounts=discount, total_tax=tax,
             total_price=total, total_line_items_price=round(subtotal + discount, 2), shipping_price=shipping, taxes_included=True,
             total_price_set={"shop_money": {"amount": f"{total:.2f}", "currency_code": "GBP"},
                              "presentment_money": {"amount": f"{total * fx:.2f}", "currency_code": pres_cur}},
             discount_codes=[{"code": code[0], "amount": f"{discount:.2f}", "type": code[1]}] if code else [],
             note_attributes=[{"name": "gift_message", "value": "Happy Christmas!"}]
             if any(r["gift_card"] for r in rows) or (d_lon.month == 12 and R.random() < 0.1) else [],
             source_name=source, landing_site=landing, referring_site=referring,
             tags="wholesale" if source == "shopify_draft_order" else "", test=is_test,
             buyer_accepts_marketing=bool(cust and cust["accepts_marketing"]), _fivetran_synced=synced(),
             _fivetran_deleted=is_test and R.random() < 0.5)
    orders.append(o)
    lines.extend(rows)
    gw = "paypal" if R.random() < 0.16 and source != "pos" else ("shopify_payments" if source != "pos" else "shopify_pos")
    tx = lambda kind, status, when, amount: transactions.append(dict(
        id=nid("tx", 7_000_000_000_000), order_id=oid, refund_id=None, kind=kind, status=status, gateway=gw, amount=round(amount, 2),
        currency=pres_cur, created_at=iso(when), test=is_test, _fivetran_synced=synced()))
    if R.random() < 0.03:
        tx("sale", "failure", t_utc - timedelta(minutes=2), total * fx)        # a declined card first
    if fin == "paid":
        tx("sale", "success", t_utc, total * fx)                               # in the PRESENTMENT currency, as Shopify records it
    elif fin == "pending":
        tx("sale", "pending", t_utc, total * fx)
    else:
        tx("authorization", "success", t_utc, total * fx)
        tx("void", "success", t_utc + timedelta(hours=3), total * fx)
    refunded = 0.0
    if cancelled and fin == "paid":
        refunded = add_refund(o, [(r, r["quantity"]) for r in rows], t_utc + timedelta(hours=R.randint(3, 30)), shipping, fx, pres_cur, gw)
    elif fin == "paid" and R.random() < 0.05:
        r = R.choice(rows)
        refunded = add_refund(o, [(r, 1)], t_utc + timedelta(days=R.randint(3, 20), hours=R.randint(0, 9)), 0.0, fx, pres_cur, gw)
        whole = len(rows) == 1 and r["quantity"] == 1 and shipping == 0
        o["financial_status"] = "refunded" if whole else "partially_refunded"
    if cust and not is_test:
        cust["orders_count"] += 1
        cust["_n"].append(o)
        if o["financial_status"] in ("paid", "partially_refunded", "refunded"):
            cust["total_spent"] = round(cust["total_spent"] + total - refunded, 2)


def landing_for(ad, click_d, has_utm):
    path = "/products/burr-grinder-one" if ad["kind"] == "launch" else R.choice(["/", "/collections/coffee", "/products/huila-washed-colombia"])
    fbclid = "fbclid=IwAR" + "".join(R.choice("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-") for _ in range(22))
    if not has_utm:
        return R.choice(["/", "/collections/coffee"]), None          # came back later by typing the address
    if ad["url_tags"] is None:
        return f"{path}?{fbclid}", "https://l.facebook.com/"
    tags = ad["url_tags"].replace("{{campaign.name}}", quote(campaign_name_on(ad, click_d))).replace("{{ad.id}}", str(ad["id"]))
    return f"{path}?{tags}&{fbclid}", R.choice(["https://l.facebook.com/", "https://l.instagram.com/", "http://m.facebook.com/"])


events = [(t, "ad", (ad, cd, hu)) for t, ad, cd, hu in ad_orders]
d = START - timedelta(days=1)
while d <= END + timedelta(days=1):                   # everything that is not Meta: direct, search, Google ads, email, POS
    for _ in range(max(0, int(R.gauss(16, 3.5) * season(d)))):
        h = R.choices(range(24), [1, 1, 1, 1, 1, 2, 3, 5, 6, 7, 7, 7, 8, 8, 7, 7, 7, 8, 9, 10, 10, 8, 5, 3])[0]
        events.append((datetime.combine(d, time(h, R.randint(0, 59), R.randint(0, 59)), LON).astimezone(UTC), "other", None))
    if d.weekday() == 5 and R.random() < 0.8:
        for _ in range(R.randint(4, 12)):            # Saturday market stall
            events.append((datetime.combine(d, time(R.randint(9, 15), R.randint(0, 59)), LON).astimezone(UTC), "pos", None))
    d += timedelta(days=1)
lo, hi = datetime.combine(START, time(0), LA).astimezone(UTC), SYNCED - timedelta(hours=1)
events = sorted((e for e in events if lo <= e[0] <= hi), key=lambda e: e[0])

OTHER = [("/", None, 34), ("/collections/coffee?utm_source=google&utm_medium=cpc&utm_campaign=brand_exact", "https://www.google.com/", 14),
         ("/products/yirgacheffe-kochere-ethiopia", "https://www.google.com/", 20), ("/blogs/brew-guides/v60", "https://www.google.co.uk/", 7),
         ("/?utm_source=klaviyo&utm_medium=email&utm_campaign=weekly_roast", None, 15),
         ("/?utm_source=instagram&utm_medium=social&utm_campaign=bio_link", "https://l.instagram.com/", 4),
         ("/products/house-espresso-blend", "https://duckduckgo.com/", 3), (None, None, 3)]
for t, kind, payload in events:
    if kind == "ad":
        landing, ref = landing_for(*payload)
        make_order(t, landing, ref)
    elif kind == "pos":
        make_order(t, None, None, source="pos")
    else:
        src = R.choices(["web", "shopify_draft_order", "294517"], [95, 2, 3])[0]   # 294517: a subscription app's id
        landing, ref, _ = R.choices(OTHER, [w for *_, w in OTHER])[0]
        make_order(t, landing if src == "web" else None, ref if src == "web" else None, source=src)

for c in customers:
    c["updated_at"] = max([c["created_at"]] + [o["updated_at"] for o in c["_n"]])

shop = [dict(id=SHOP_ID, name="Fernhill Coffee", domain="fernhillcoffee.example", currency="GBP", iana_timezone="Europe/London",
             country_code="GB", taxes_included=True, plan_name="shopify", created_at=iso(datetime(2024, 2, 1, 10, tzinfo=UTC)),
             _fivetran_synced=synced())]

write("shopify", "shop", shop, list(shop[0]))
write("shopify", "customer", customers, ["id", "email", "first_name", "last_name", "phone", "accepts_marketing", "state", "tags",
                                         "default_address", "orders_count", "total_spent", "created_at", "updated_at",
                                         "_fivetran_synced", "_fivetran_deleted"])
write("shopify", "product", products, list(products[0]))
write("shopify", "product_variant", variants, [k for k in variants[0] if k != "_p"])
write("shopify", "order", orders, list(orders[0]))
write("shopify", "order_line", lines, [k for k in lines[0] if k != "_vat"])
write("shopify", "refund", refunds, list(refunds[0]))
write("shopify", "order_line_refund", refund_lines, list(refund_lines[0]))
write("shopify", "transaction", transactions, list(transactions[0]))
write("meta_ads", "account_history", account_rows, list(account_rows[0]))
write("meta_ads", "campaign_history", campaign_rows, list(campaign_rows[0]))
write("meta_ads", "ad_set_history", adset_rows, list(adset_rows[0]))
write("meta_ads", "ad_history", ad_rows, list(ad_rows[0]))
write("meta_ads", "creative_history", creative_rows, list(creative_rows[0]))
write("meta_ads", "basic_ad", basic_ad, list(basic_ad[0]))
write("meta_ads", "basic_ad_actions", actions, list(actions[0]))
write("meta_ads", "basic_ad_action_values", action_values, list(action_values[0]))
