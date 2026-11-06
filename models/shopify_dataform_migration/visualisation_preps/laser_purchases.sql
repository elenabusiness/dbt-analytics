{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "visualisation_preps"
}

with base_orders as (
select 
customer_id_original customer_id
,order_id
,order_date
,order_timestamp
,sum(orderline_revenue) revenue
,(select discount_codes_unnested from unnest (discount_codes) discount_codes_unnested where trim(lower(discount_codes_unnested)) = 'laser50') laser_50_discount_code
,countif(lower(orderline_name) = 'portable laser therapy') lasers_in_order
,count (distinct order_id) over (partition by customer_id_original) total_customer_orders
,rank() over (partition by customer_id_original order by order_timestamp asc) = 1 is_first_order
from {{ ref('base_orderlines') }}
where customer_id_original not in ('5833728196743','3405471776903','5032305098887')
group by 
customer_id_original
,order_id
,order_date
,order_timestamp
,laser_50_discount_code
)

, ltv as (
select 
* 
,sum(revenue) over (partition by customer_id order by order_timestamp asc) ltv_running
,row_number() over (partition by customer_id order by order_timestamp asc) order_number
from base_orders
)

,laser_50_table as
(select 
customer_id
,lag (ltv_running) over (partition by customer_id order by order_timestamp asc) ltv
,lag (order_number) over (partition by customer_id order by order_timestamp asc) number_of_orders
,date_diff(order_date, lag (order_date) over (partition by customer_id order by order_timestamp asc),day) days_after_previous_order
from ltv
qualify laser_50_discount_code is not null
)


,laser_purchases_table as
(select 
customer_id, order_id
,ifnull(lag (ltv_running) over (partition by customer_id order by order_timestamp asc),0) ltv
,ifnull(lag (order_number) over (partition by customer_id order by order_timestamp asc),0) number_of_orders
,date_diff(order_date, lag (order_date) over (partition by customer_id order by order_timestamp asc),day) days_after_previous_order
from ltv
qualify lasers_in_order >0 
)

select 
customer_id, order_id, ltv, number_of_orders, days_after_previous_order
from
(select *
,mod(count(*) over (),2) =0 is_total_row_count_even
,count(*) over () total_row_count
from laser_purchases_table
)