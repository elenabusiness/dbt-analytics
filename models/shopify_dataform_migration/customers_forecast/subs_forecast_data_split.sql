{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table"}

select 1 as ttt


-- config {
--   type: "table",
--   schema: "customers_forecast"}


-- select
-- is_sub
-- ,vwo
-- ,sub_frequency_days
-- ,discount_percent_first_order
-- ,discount_percent_max
-- ,discount_percent_total
-- ,price
-- ,sub_ids_other_active
-- ,is_new_customer
-- ,sub_ids_cancelled_before 
-- ,sub_ids_cancelled_before_rate
-- ,orders_refunded_before_rate
-- ,orders_refunded_sequentially_latest
-- ,orders_before_from_customer
-- ,payment_offset_days_median_days
-- ,customer_had_early_cancellation
-- ,early_cancellation_avg_rate
-- ,orders_successfull_followup
-- ,is_following_1_order_success
-- ,is_following_2_order_success
-- ,is_following_3_order_success
-- ,is_following_4_order_success
-- ,is_following_5_order_success
-- ,is_following_6_order_success
-- ,split
-- from  {{ ref('subs_forecast_data_split_preps') }} 
