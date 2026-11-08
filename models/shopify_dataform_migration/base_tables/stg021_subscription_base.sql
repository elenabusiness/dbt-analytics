{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with sub_ids as(
  select  
  distinct 
  customer_id recharge_customer_id
  ,customer_id shopify_customer_id
  ,external_product_id:ecommerce::string shopify_order_id
  ,id::string sub_id
  ,external_variant_id:ecommerce::string shopify_variant_id 
  from {{source ('subscription_source','subscriptions')}}
)

, next_payment_date as(
  select distinct external_variant_id:ecommerce::string shopify_variant_id, cast(id as string) sub_id,
  lower(status) sub_status, charge_interval_frequency,order_interval_unit, cast(cancelled_at as timestamp) sub_cancellation_date, cast(updated_at as date) sub_update_date, cancelled_at,cast(next_charge_scheduled_at as date) recharge_expected_next_order_date
  from {{source ('subscription_source','subscriptions')}}
)

select * 
,rank () over (partition by recharge_customer_id,shopify_order_id, shopify_variant_id order by sub_id) sub_rank
from
(select 
sub_ids.*
,next_payment_date.sub_status
,next_payment_date.charge_interval_frequency
,next_payment_date.order_interval_unit
,next_payment_date.sub_cancellation_date
,next_payment_date.sub_update_date
,next_payment_date.recharge_expected_next_order_date
from sub_ids
left join next_payment_date
on sub_ids.sub_id = next_payment_date.sub_id 
)
where sub_id is not null and shopify_order_id is not null
