-- 02_raw_shopify_meta.sql: landing tables for the Shopify + Meta Ads practice data (fictional brand: Fernhill Coffee).
-- Run by scripts/load_marketing.py as role LOADER; idempotent.
--
-- The shape follows how an ELT connector (Fivetran-style) lands these sources: one table per API object, typed
-- columns, JSON kept as VARIANT, *_HISTORY tables with every version of a Meta object, _fivetran_synced and
-- _fivetran_deleted. Plus this lab's three audit columns (_file_name, _file_row, _loaded_at), as in RAW.SHOP.
-- Timestamps arrive in UTC. Meta's DATE columns are in the ad account's own time zone (see ACCOUNT_HISTORY).
-- Note "ORDER": a reserved word, so the table name has to be quoted everywhere: raw.shopify."ORDER".

create schema if not exists raw.shopify;
create schema if not exists raw.meta_ads;

create file format if not exists raw.shopify.csv_with_header
  type = csv skip_header = 1 field_optionally_enclosed_by = '"' empty_field_as_null = true null_if = ('');
create file format if not exists raw.meta_ads.csv_with_header
  type = csv skip_header = 1 field_optionally_enclosed_by = '"' empty_field_as_null = true null_if = ('');
create stage if not exists raw.shopify.files  file_format = raw.shopify.csv_with_header;
create stage if not exists raw.meta_ads.files file_format = raw.meta_ads.csv_with_header;

-- ─────────────── Shopify ───────────────
create table if not exists raw.shopify.shop (
  id number, name varchar, domain varchar, currency varchar, iana_timezone varchar, country_code varchar,
  taxes_included boolean, plan_name varchar, created_at timestamp_tz, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.customer (
  id number, email varchar, first_name varchar, last_name varchar, phone varchar, accepts_marketing boolean,
  state varchar, tags varchar, default_address variant, orders_count number, total_spent number(12,2),
  created_at timestamp_tz, updated_at timestamp_tz, _fivetran_synced timestamp_tz, _fivetran_deleted boolean,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.product (
  id number, title varchar, handle varchar, product_type varchar, vendor varchar, status varchar, tags varchar,
  created_at timestamp_tz, updated_at timestamp_tz, published_at timestamp_tz, _fivetran_synced timestamp_tz,
  _fivetran_deleted boolean, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.product_variant (
  id number, product_id number, title varchar, sku varchar, price number(12,2), compare_at_price number(12,2),
  inventory_quantity number, created_at timestamp_tz, updated_at timestamp_tz, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify."ORDER" (
  id number, name varchar, order_number number, email varchar, customer_id number,
  created_at timestamp_tz, processed_at timestamp_tz, updated_at timestamp_tz, cancelled_at timestamp_tz,
  cancel_reason varchar, closed_at timestamp_tz, financial_status varchar, fulfillment_status varchar,
  currency varchar, presentment_currency varchar, subtotal_price number(12,2), total_discounts number(12,2),
  total_tax number(12,2), total_price number(12,2), total_line_items_price number(12,2), shipping_price number(12,2),
  taxes_included boolean, total_price_set variant, discount_codes variant, note_attributes variant,
  source_name varchar, landing_site varchar, referring_site varchar, tags varchar, test boolean,
  buyer_accepts_marketing boolean, _fivetran_synced timestamp_tz, _fivetran_deleted boolean,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.order_line (
  id number, order_id number, product_id number, variant_id number, sku varchar, title varchar, variant_title varchar,
  vendor varchar, quantity number, price number(12,2), total_discount number(12,2), gift_card boolean, taxable boolean,
  requires_shipping boolean, fulfillable_quantity number, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.refund (
  id number, order_id number, created_at timestamp_tz, processed_at timestamp_tz, note varchar, restock boolean,
  _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.order_line_refund (
  id number, refund_id number, order_line_id number, quantity number, subtotal number(12,2), total_tax number(12,2),
  restock_type varchar, _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.transaction (
  id number, order_id number, refund_id number, kind varchar, status varchar, gateway varchar, amount number(12,2),
  currency varchar, created_at timestamp_tz, test boolean, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.order_shipping_line (
  id number, order_id number, title varchar, code varchar, source varchar, carrier_identifier varchar, price number(12,2),
  discounted_price number(12,2), price_set variant, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

-- Money columns are text here, as in Shopify's API, and negative for money going back. The *_set columns are flattened.
create table if not exists raw.shopify.order_adjustment (
  id number, order_id number, refund_id number, kind varchar, reason varchar, amount varchar, tax_amount varchar,
  amount_set_shop_money_amount varchar, amount_set_shop_money_currency_code varchar,
  amount_set_presentment_money_amount varchar, amount_set_presentment_money_currency_code varchar,
  tax_amount_set_shop_money_amount varchar, tax_amount_set_shop_money_currency_code varchar,
  tax_amount_set_presentment_money_amount varchar, tax_amount_set_presentment_money_currency_code varchar,
  _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.shopify.disputes (
  id number, order_id number, type varchar, status varchar, reason varchar, network_reason_code varchar, amount varchar,
  currency varchar, initiated_at timestamp_tz, evidence_due_by timestamp_tz, evidence_sent_on timestamp_tz,
  finalized_on timestamp_tz, shop_url varchar, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

-- ─────────────── Meta Ads ───────────────
create table if not exists raw.meta_ads.account_history (
  id number, name varchar, account_status number, currency varchar, timezone_name varchar, business_country_code varchar,
  created_time timestamp_tz, updated_time timestamp_tz, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.campaign_history (
  id number, account_id number, name varchar, objective varchar, status varchar,
  daily_budget number, lifetime_budget number,                  -- in the account currency's MINOR units (pence)
  buying_type varchar, start_time timestamp_tz, stop_time timestamp_tz, created_time timestamp_tz,
  updated_time timestamp_tz, _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.ad_set_history (
  id number, campaign_id number, account_id number, name varchar, status varchar, daily_budget number,
  optimization_goal varchar, billing_event varchar, bid_strategy varchar, targeting variant,
  start_time timestamp_tz, end_time timestamp_tz, created_time timestamp_tz, updated_time timestamp_tz,
  _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.ad_history (
  id number, ad_set_id number, campaign_id number, account_id number, name varchar, status varchar, creative_id number,
  created_time timestamp_tz, updated_time timestamp_tz, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.creative_history (
  id number, account_id number, name varchar, title varchar, body varchar, call_to_action_type varchar,
  object_type varchar, link_url varchar, url_tags varchar, _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.basic_ad (
  _fivetran_id varchar, ad_id number, date date, account_id number, ad_name varchar, adset_name varchar,
  impressions number, inline_link_clicks number, reach number, frequency float, spend number(12,2),
  cpc float, cpm float, ctr float, _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.basic_ad_actions (
  _fivetran_id varchar, ad_id number, date date, index number, action_type varchar, value number,
  _7_d_click number, _1_d_view number, _fivetran_synced timestamp_tz, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.meta_ads.basic_ad_action_values (
  _fivetran_id varchar, ad_id number, date date, index number, action_type varchar, value number(12,2),
  _7_d_click number(12,2), _1_d_view number(12,2), _fivetran_synced timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);
