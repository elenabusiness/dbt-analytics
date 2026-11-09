-- 04_raw_intelligems.sql: landing tables for the Intelligems (A/B testing app) practice data, Fernhill Coffee.
-- Run by scripts/load_intelligems.py as role LOADER; idempotent.
--
-- RAW.INTELLIGEMS.INTELLIGEMS_DATA_IMPORT_RAW: Intelligems' order export, every weekly export file in one table
-- (in BigQuery this was an external table over a bucket of CSV files). One row per test x order x export;
-- loaded_at_ts says which export a row came from.
-- RAW.GOOGLE_SHEETS.IG_OUT_OF_STOCK_<band>_ORDERS_TABLE: one older test's results pasted into a Google Sheet, one
-- table per tab (in BigQuery these were sheet-backed external tables). Every column is text except IS_OUTLIER.
-- Both join to RAW.SHOPIFY."ORDER" on order_id = "ORDER".id (text here, a number in Shopify).
-- Plus this lab's three audit columns, as in RAW.SHOP.

create schema if not exists raw.intelligems;
create file format if not exists raw.intelligems.csv_with_header
  type = csv skip_header = 1 field_optionally_enclosed_by = '"' empty_field_as_null = true null_if = ('');
create stage if not exists raw.intelligems.files file_format = raw.intelligems.csv_with_header;

create table if not exists raw.intelligems.intelligems_data_import_raw (
  ig_id varchar, order_id varchar, test_id varchar, test_name varchar, variant_id varchar, variant_name varchar,
  is_excluded boolean, order_value_z_score float, loaded_at_ts timestamp_tz,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create schema if not exists raw.google_sheets;
create file format if not exists raw.google_sheets.csv_with_header
  type = csv skip_header = 1 field_optionally_enclosed_by = '"' empty_field_as_null = true null_if = ('');
create stage if not exists raw.google_sheets.files file_format = raw.google_sheets.csv_with_header;

create table if not exists raw.google_sheets.ig_out_of_stock_0_35_orders_table (
  variation_name varchar, order_id varchar, order_name varchar, customer_id varchar, order_created_time varchar,
  shipping_method varchar, test_order varchar, total_units varchar, total_test_units varchar, product_list_price varchar,
  product_discount varchar, intelligems_price_test_discount varchar, net_product_revenue varchar, net_shipping_revenue varchar, net_revenue varchar,
  total_tax varchar, net_revenue_incl_tax_and_tip varchar, product_cogs varchar, shipping_cost varchar, transaction_fee varchar,
  gross_profit varchar, order_value_z_score varchar, is_outlier boolean, subscription_order_type varchar, new_vs_returning_visitor varchar,
  device_type varchar, channel varchar, timezone varchar, label varchar,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.google_sheets.ig_out_of_stock_35_65_orders_table (
  variation_name varchar, order_id varchar, order_name varchar, customer_id varchar, order_created_time varchar,
  shipping_method varchar, test_order varchar, total_units varchar, total_test_units varchar, product_list_price varchar,
  product_discount varchar, intelligems_price_test_discount varchar, net_product_revenue varchar, net_shipping_revenue varchar, net_revenue varchar,
  total_tax varchar, net_revenue_incl_tax_and_tip varchar, product_cogs varchar, shipping_cost varchar, transaction_fee varchar,
  gross_profit varchar, order_value_z_score varchar, is_outlier boolean, subscription_order_type varchar, new_vs_returning_visitor varchar,
  device_type varchar, channel varchar, timezone varchar, label varchar,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.google_sheets.ig_out_of_stock_65_100_orders_table (
  variation_name varchar, order_id varchar, order_name varchar, customer_id varchar, order_created_time varchar,
  shipping_method varchar, test_order varchar, total_units varchar, total_test_units varchar, product_list_price varchar,
  product_discount varchar, intelligems_price_test_discount varchar, net_product_revenue varchar, net_shipping_revenue varchar, net_revenue varchar,
  total_tax varchar, net_revenue_incl_tax_and_tip varchar, product_cogs varchar, shipping_cost varchar, transaction_fee varchar,
  gross_profit varchar, order_value_z_score varchar, is_outlier boolean, subscription_order_type varchar, new_vs_returning_visitor varchar,
  device_type varchar, channel varchar, timezone varchar, label varchar,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.google_sheets.ig_out_of_stock_100_120_orders_table (
  variation_name varchar, order_id varchar, order_name varchar, customer_id varchar, order_created_time varchar,
  shipping_method varchar, test_order varchar, total_units varchar, total_test_units varchar, product_list_price varchar,
  product_discount varchar, intelligems_price_test_discount varchar, net_product_revenue varchar, net_shipping_revenue varchar, net_revenue varchar,
  total_tax varchar, net_revenue_incl_tax_and_tip varchar, product_cogs varchar, shipping_cost varchar, transaction_fee varchar,
  gross_profit varchar, order_value_z_score varchar, is_outlier boolean, subscription_order_type varchar, new_vs_returning_visitor varchar,
  device_type varchar, channel varchar, timezone varchar, label varchar,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists raw.google_sheets.ig_out_of_stock_120_plus_orders_table (
  variation_name varchar, order_id varchar, order_name varchar, customer_id varchar, order_created_time varchar,
  shipping_method varchar, test_order varchar, total_units varchar, total_test_units varchar, product_list_price varchar,
  product_discount varchar, intelligems_price_test_discount varchar, net_product_revenue varchar, net_shipping_revenue varchar, net_revenue varchar,
  total_tax varchar, net_revenue_incl_tax_and_tip varchar, product_cogs varchar, shipping_cost varchar, transaction_fee varchar,
  gross_profit varchar, order_value_z_score varchar, is_outlier boolean, subscription_order_type varchar, new_vs_returning_visitor varchar,
  device_type varchar, channel varchar, timezone varchar, label varchar,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);
