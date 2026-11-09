-- 03_raw_recharge.sql: landing tables for the Recharge (subscription app) practice data, Fernhill Coffee.
-- Run by scripts/load_recharge.py as role LOADER; idempotent.
--
-- The shape follows how Stitch lands Recharge: one table per API object, nested objects and arrays kept as VARIANT
-- (CUSTOMER, EXTERNAL_ORDER_ID, LINE_ITEMS ...), and Stitch's own columns _sdc_extracted_at, _sdc_received_at,
-- _sdc_batched_at, _sdc_sequence, _sdc_table_version. Plus this lab's three audit columns, as in RAW.SHOP.
-- Timestamps arrive in UTC. NEXT_CHARGE_SCHEDULED_AT is a plain date.
-- Joins to RAW.SHOPIFY through the external ids: CUSTOMER:external_customer_id:ecommerce, EXTERNAL_ORDER_ID:ecommerce,
-- LINE_ITEMS[n]:external_variant_id:ecommerce (strings inside the JSON; Shopify's ids are numbers).

create schema if not exists raw.recharge;

create file format if not exists raw.recharge.csv_with_header
  type = csv skip_header = 1 field_optionally_enclosed_by = '"' empty_field_as_null = true null_if = ('');
create stage if not exists raw.recharge.files file_format = raw.recharge.csv_with_header;

create table if not exists raw.recharge.customers (
  id number, email varchar, external_customer_id variant, first_name varchar, last_name varchar, phone varchar,
  hash varchar, created_at timestamp_tz, updated_at timestamp_tz, first_charge_processed_at timestamp_tz,
  subscriptions_active_count number, subscriptions_total_count number, has_valid_payment_method boolean,
  has_payment_method_in_dunning boolean, tax_exempt boolean,
  _sdc_extracted_at timestamp_tz, _sdc_received_at timestamp_tz, _sdc_batched_at timestamp_tz, _sdc_sequence number,
  _sdc_table_version number, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.recharge.addresses (
  id number, customer_id number, first_name varchar, last_name varchar, address1 varchar, city varchar,
  province varchar, country_code varchar, zip varchar, phone varchar, created_at timestamp_tz, updated_at timestamp_tz,
  _sdc_extracted_at timestamp_tz, _sdc_received_at timestamp_tz, _sdc_batched_at timestamp_tz, _sdc_sequence number,
  _sdc_table_version number, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.recharge.subscriptions (
  id number, address_id number, customer_id number, analytics_data variant, cancellation_reason varchar,
  cancellation_reason_comments varchar, cancelled_at timestamp_tz, charge_interval_frequency number,
  created_at timestamp_tz, expire_after_specific_number_of_charges number, external_product_id variant,
  external_variant_id variant, has_queued_charges boolean, is_prepaid boolean, is_skippable boolean,
  is_swappable boolean, max_retries_reached boolean, next_charge_scheduled_at date, order_day_of_month number,
  order_day_of_week number, order_interval_frequency number, order_interval_unit varchar,
  presentment_currency varchar, price number(12,2), product_title varchar, properties variant, quantity number,
  sku varchar, status varchar, updated_at timestamp_tz, variant_title varchar,
  _sdc_extracted_at timestamp_tz, _sdc_received_at timestamp_tz, _sdc_batched_at timestamp_tz, _sdc_sequence number,
  _sdc_table_version number, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.recharge.orders (
  id number, address_id number, charge variant, created_at timestamp_tz, processed_at timestamp_tz,
  scheduled_at timestamp_tz, updated_at timestamp_tz, currency varchar, customer variant, discounts variant,
  external_order_id variant, external_order_name variant, external_order_number variant, is_prepaid boolean,
  line_items variant, shipping_address variant, status varchar, subtotal_price number(12,2), tags varchar,
  total_discounts number(12,2), total_price number(12,2), total_refunds number(12,2), total_tax number(12,2),
  type varchar,
  _sdc_extracted_at timestamp_tz, _sdc_received_at timestamp_tz, _sdc_batched_at timestamp_tz, _sdc_sequence number,
  _sdc_table_version number, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);
