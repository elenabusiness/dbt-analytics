{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with order_lines_with_sub_ids as (
select order_lines.* exclude (subscription_rank_within_order)
,subs.recharge_customer_id
,subs.sub_id
,subs.sub_status
,cast(subs.charge_interval_frequency as int) as sub_interval_frequency
,subs.order_interval_unit as sub_interval_unit
,subs.sub_cancellation_date::date as sub_cancellation_date
,subs.sub_update_date::date as sub_update_date
,recharge_expected_next_order_date
from {{ ref('stg0205_orderline_test_names_from_ig_raw_data_upload') }} as order_lines
left join {{ ref('stg021_subscription_base') }} as subs
  on order_lines.customer_id = subs.shopify_customer_id and order_lines.order_id = subs.shopify_order_id and order_lines.orderline_variant_id = subs.shopify_variant_id and order_lines.subscription_rank_within_order = subs.sub_rank
)

,sub_details as (
select *
,count(distinct iff(is_sub, order_id, null)) over (partition by sub_id, customer_id) = 1 and sub_status = 'cancelled' as is_sub_churn_after_one_payment
,ifnull(max(is_sub) over (partition by order_id), false) as order_has_sub
from
(select *
,sub_id is not null and sub_status is not null and sub_interval_frequency is not null and sub_interval_unit is not null as is_sub
,ifnull(concat(sub_interval_frequency, ' ', sub_interval_unit, iff(sub_interval_frequency != 1, 's', '')), 'onetime') as sub_frequency
from order_lines_with_sub_ids)
)

select * from sub_details
