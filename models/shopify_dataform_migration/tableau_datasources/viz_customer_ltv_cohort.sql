{{ config(
  materialized='table',
  
  ) }}
with base_metrics as (
select 
-- cm dash
customer_id
,order_id
,customer_reached_first_billing
,dog_weight_from_product
,customer_first_order_date first_order_date
,is_first_order
,is_retained_customer
,source_type
,sub_frequency_group
,sub_type
-- ,test_no vwo_test_no
-- ,test_variant vwo_variant
,days_after_first_order
,days_to_positive_cm
,orderline_marketing_cost marketing_cost
,months_after_first_order
,orderline_cm order_cm
,orderline_cm_less_cac order_cm_less_cac
,weeks_after_first_order
,is_first_order_original
-- test 267 dash
,variant_title



-- test 267 dash
,days15_after_first_order
,sub_frequency

-- cro dash
,is_churned_after_first_order
,is_churned_after_second_order
,is_second_order
,is_second_order_date_unknown
,is_second_order_success
,is_third_order
,is_third_order_date_unknown
,is_third_order_success
,time_window_for_second_order_complete
,time_window_for_third_order_complete
,orderline_paid_by_customer order_paid_by_customer
,days_to_sub_churn
,customer_has_subscription
,sku

-- new tests dashboard
,customer_first_sub_order_date
,is_sub_churn_after_one_payment
,is_subscriber
,order_date
,order_has_dispute
,order_has_refund
,orderline_revenue order_revenue
,orderline_dispute_amount order_dispute_amount
,orderline_total_refund order_total_refund
from {{ ref('customer_ltv_cohort_order_line_level') }}

)

,offer_tubs as(
select * 

from base_metrics
)

-- ,variant_as_arr as (
-- select * except(vwo_variant_arr)
-- ,array(select distinct vwo_variant from unnest(vwo_variant_arr) vwo_variant where vwo_variant is not null and vwo_variant != '1') vwo_variant_arr
-- from (SELECT 
-- *
-- ,iff(vwo_variant = '1'
--   ,iff(
--     count(distinct vwo_variant) over (partition by vwo_test_no) = 0
--     ,null
--     ,array_agg(vwo_variant) over (partition by vwo_test_no)
--   )
-- ,iff(vwo_variant is null, null, [vwo_variant])
-- ) vwo_variant_arr
-- from offer_tubs
-- where first_order_date >='2023-01-01' 
-- ))

-- ,variant_as_arr_unnested as(
-- select 
-- * except (vwo_variant_arr,vwo_variant)
-- ,iff(vwo_variant = '1', 'Control',vwo_variant) vwo_variant
-- from variant_as_arr
-- left join unnest(vwo_variant_arr) vwo_variant_filter
-- )

-- select * 
-- ,rank() over (partition by vwo_test_no, vwo_variant,customer_id, order_id,sku order by vwo_variant_filter asc) = 1 is_variant_first_instance
-- from variant_as_arr_unnested

select * 
from offer_tubs