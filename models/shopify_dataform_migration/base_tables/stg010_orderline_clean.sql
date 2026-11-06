{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with unnested_data as (
select 
orders.*
,orderlines.order_id order_id_from_orderlines_table
,cast (id as string) orderline_id
,title orderline_name
,sku
,variant_id::string orderline_variant_id
,ifnull(cast(price as FLOAT)*cast(quantity as INT),0) orderline_price
,ifnull(cast(quantity as INT),0) orderline_quantity
,ifnull(sum(cast(quantity as INT)) over (partition by id),0) order_total_quantity
,ifnull(cast(total_discount as FLOAT),0) orderline_discount
,nullif(variant_title,'') orderline_variant_title
from  {{ source('shopify_source', 'order_line') }} orderlines
left join {{ref ('stg009_orders_clean')}} orders
on orderlines.order_id = orders.order_id 
)

,order_lines as 
(select * exclude (order_tax, order_shipping_cost)
,order_tax*orderline_share_in_order orderline_tax
,order_shipping_cost*orderline_share_in_order orderline_shipping_cost
from
(select *  exclude(order_total_quantity)
,dense_rank() over (partition by customer_id order by order_timestamp asc) = 1 is_first_order
,dense_rank() over (partition by customer_id order by order_timestamp desc) = 1 is_last_order
,rank() over (partition by customer_id, order_id, orderline_variant_id  order by orderline_id asc) subscription_rank_within_order
,div0(orderline_quantity,order_total_quantity) orderline_share_in_order
from  unnested_data
))

, source_url_clean as (
select 
* exclude (source_url)
,regexp_replace(source_url, '\\?.*$', '') as source_url
from order_lines
)

select * from order_lines


