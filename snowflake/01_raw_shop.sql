-- 01_raw_shop.sql: the landing tables for the practice shop data. Run by scripts/load_raw.py
-- (and by the Airflow DAG) as role LOADER; idempotent.
--
-- Pattern: land the files as they come, add three audit columns, never transform here.
--   _file_name   which file a row came from  (metadata$filename)
--   _file_row    its row number in that file (metadata$file_row_number)
--   _loaded_at   when it landed              (current_timestamp at COPY time)
-- The same order can land twice (batch 2 re-sends changed orders). Deduping is dbt's job, not the loader's.

create schema if not exists raw.shop;
use schema raw.shop;

create file format if not exists csv_with_header
  type = csv skip_header = 1 field_optionally_enclosed_by = '"'
  empty_field_as_null = true null_if = ('') trim_space = false;

-- an internal stage: Snowflake-managed storage you PUT files into before COPY INTO reads them
create stage if not exists shop_files file_format = csv_with_header;

create table if not exists customers (
  id number, email varchar, first_name varchar, last_name varchar, country varchar,
  created_at varchar, updated_at varchar, accepts_marketing boolean,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists products (
  id number, sku varchar, title varchar, product_type varchar, price number(10,2), is_subscribable boolean,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists subscriptions (
  id number, customer_id number, product_id number, status varchar, created_at varchar, cancelled_at varchar,
  interval_days number, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists orders (
  id number, customer_id number, created_at varchar, updated_at varchar, financial_status varchar,
  fulfillment_status varchar, currency varchar, total_price number(10,2), discount_code varchar,
  source_name varchar, cancelled_at varchar, _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists order_lines (
  id number, order_id number, product_id number, quantity number, price number(10,2), discount number(10,2),
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);

create table if not exists ad_spend (
  date date, channel varchar, campaign varchar, spend number(10,2), impressions number, clicks number,
  _file_name varchar, _file_row number, _loaded_at timestamp_ltz);
