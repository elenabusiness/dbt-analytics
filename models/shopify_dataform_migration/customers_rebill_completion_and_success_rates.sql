{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"
}


with sub_orders_agg as (
select
cohort_month
,first_order_date
,order_rank
,sub_frequency_group
,accepts_marketing, amped_discount_code, email_exclusion_test,free_gift
,count(distinct customer_id) customers
,count(distinct if(is_order_complete,customer_id,null)) customers_completed_order
,count(distinct if(is_order_success,customer_id,null)) customers_with_order_success
from {{ ref('customers_rebill_stats_stg04_with_klaviyo_props') }}
group by
cohort_month
,first_order_date
,order_rank
,sub_frequency_group
,accepts_marketing, amped_discount_code, email_exclusion_test,free_gift
)

select * from sub_orders_agg