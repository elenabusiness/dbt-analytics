{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with order_adjustments as (
select * exclude (refund_date, order_adjustments_tax, order_adjustments_ref_shop_money, order_adjustments_ref_amount)
,min(refund_date) as refund_date
,sum(ifnull(order_adjustments_tax, 0)) as order_adjustments_tax
,sum(iff(round(order_adjustments_ref_shop_money, 2) = 0, order_adjustments_ref_amount, order_adjustments_ref_shop_money)) as order_adjustments_ref
from
(select
cast(r.order_id as string) as order_id
,convert_timezone('America/Los_Angeles', r.created_at)::date as refund_date
,ifnull(-try_cast(oa.tax_amount_set_presentment_money_amount as float), 0) as order_adjustments_tax
,ifnull(-try_cast(oa.amount_set_shop_money_amount as float), 0) as order_adjustments_ref_shop_money
,ifnull(-try_cast(oa.amount as float), 0) as order_adjustments_ref_amount
from {{ source('shopify_source', 'refund') }} as r
left join {{ source('shopify_source', 'order_adjustment') }} as oa
  on r.id = oa.refund_id
)
group by order_id
)

select *
from order_adjustments
