{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select * except (is_last_order,recharge_expected_next_order_date,expected_next_order_date_orderline_level)
,if (is_last_order
    ,greatest(coalesce(expected_next_order_date_orderline_level,recharge_expected_next_order_date),coalesce(recharge_expected_next_order_date,expected_next_order_date_orderline_level))
    ,expected_next_order_date_orderline_level) expected_next_order_date_orderline_level
from 
(select *
,ifnull(
case
    when sub_status = 'cancelled' then null
    WHEN sub_interval_unit = 'day' THEN DATE_ADD(order_date, INTERVAL sub_interval_frequency DAY)
    WHEN sub_interval_unit = 'week' THEN DATE_ADD(order_date, INTERVAL sub_interval_frequency week)
    WHEN sub_interval_unit = 'month' THEN DATE_ADD(order_date, INTERVAL sub_interval_frequency MONTH)
END, 
CASE
    WHEN nosub_interval_unit = 'day' THEN DATE_ADD(order_date, INTERVAL nosub_interval_frequency DAY)
    WHEN nosub_interval_unit = 'week' THEN DATE_ADD(order_date, INTERVAL nosub_interval_frequency week)
    WHEN nosub_interval_unit = 'month' THEN DATE_ADD(order_date, INTERVAL nosub_interval_frequency MONTH)
END) expected_next_order_date_orderline_level
from {{ ref('stg060_orderline_enhanced') }}
)