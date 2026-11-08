{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select *
,orderline_revenue-orderline_cogs-orderline_fulfillment_cost-orderline_marketing_cost orderline_cm
,orderline_revenue-orderline_cogs-orderline_fulfillment_cost orderline_cm_less_cac
from
(select *
,ifnull(DIV0(iff(is_first_order,ads_spend.cost,null),count(distinct iff(is_first_order,customer_id,null)) over (partition by order_lines.order_date))*orderline_share_in_order,0) orderline_marketing_cost
from {{ ref('stg100_with_new_acquisition_after_60_days') }} order_lines
left join {{ ref('stg101_marketing_spend_by_date') }} ads_spend
on order_lines.order_date = ads_spend.date
)