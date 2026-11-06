{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with order_shipping_lines as (
select distinct
convert_timezone('America/Los_Angeles', o.created_at)::date as order_date
,o.id as order_id
,lower(sl.title) as shipping_type
from {{ source('shopify_source', 'ORDER') }} as o
left join {{ source('shopify_source', 'order_shipping_line') }} as sl
  on o.id = sl.order_id
)

,shipping_lines_with_rules as (
select distinct
order_date, order_id, shipping_type,
first_value(ifnull(fulfillment_cost, 0)) over (partition by order_date, order_id, shipping_type order by rule_order asc) as fulfillment_cost
from
(select *
,rlike(ifnull(lower(shipping_type), 'na'), lower(shipping_type_regexp)) as shipping_type_contains_rule
from order_shipping_lines
left join {{ ref('stg041_fulfillment_cost_regexp_rules_by_date') }} as regexp_rules
  on order_shipping_lines.order_date = regexp_rules.date
) where shipping_type_contains_rule
)

,most_expensive_shipping as (
select *
,row_number() over (partition by order_id order by fulfillment_cost desc) = 1 as is_most_expensive
from shipping_lines_with_rules
)

,order_fulfillment_cost as (
select
order_id, fulfillment_cost as order_fulfillment_cost
from most_expensive_shipping
where is_most_expensive
)

select * from order_fulfillment_cost
