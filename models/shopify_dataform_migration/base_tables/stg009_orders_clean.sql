{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}


select 
*
,date(order_timestamp) order_date
from
(select 
cast (id as STRING) as order_id
,cast (name as string) as order_name
,cast (order_number as string) as order_number
,least(created_at, processed_at, updated_at) order_timestamp
,cast (customer_id as string) as customer_id
,cast(subtotal_price as FLOAT) subtotal_price
,cast(total_discounts as FLOAT) total_discounts
,cast(total_tax as FLOAT) order_tax
,cast(total_price as FLOAT) total_price
,cast(total_line_items_price as FLOAT) total_line_items_price
,cast(shipping_price as FLOAT) order_shipping_cost
,source_name 
,concat ('First Name',email) first_name
,concat ('Second Name',email) second_name
,email
,referring_site source_url
,'dog weight dummy' dog_weight
,'dog size dummy' dog_size
{# ,* exclude(id,name, order_number,customer_id) #}
from  {{ source('shopify_source', 'ORDER') }}
{# where order_id = '5800000000009' #}
)