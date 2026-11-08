{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select * exclude (is_last_order,recharge_expected_next_order_date,expected_next_order_date_orderline_level)
,iff (is_last_order
    ,greatest(coalesce(expected_next_order_date_orderline_level,recharge_expected_next_order_date),coalesce(recharge_expected_next_order_date,expected_next_order_date_orderline_level))
    ,expected_next_order_date_orderline_level) expected_next_order_date_orderline_level
from 
(select *
,ifnull(
case
    when sub_status = 'cancelled' then null
    WHEN sub_interval_unit = 'day' THEN DATEADD(day, sub_interval_frequency, order_date)
    WHEN sub_interval_unit = 'week' THEN DATEADD(week, sub_interval_frequency, order_date)
    WHEN sub_interval_unit = 'month' THEN DATEADD(month, sub_interval_frequency, order_date)
END, 
CASE
    WHEN nosub_interval_unit = 'day' THEN DATEADD(day, sub_interval_frequency, order_date)
    WHEN nosub_interval_unit = 'week' THEN DATEADD(week, sub_interval_frequency, order_date)
    WHEN nosub_interval_unit = 'month' THEN DATEADD(month, sub_interval_frequency, order_date)
END) expected_next_order_date_orderline_level
from
(select *
,decode(mod(abs(hash(order_id)), 3), 0, 'day', 1, 'week', 'month') nosub_interval_unit
,mod(abs(hash(order_id, 'count')), 3) + 1 nosub_interval_frequency
from {{ ref('stg060_orderline_enhanced') }})
)