{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with orderline_refunds as (
select * exclude (refund_date)
,min(refund_date) over (partition by order_id) as refund_date
from
(select
cast(r.order_id as string) as order_id
,olr.order_line_id as orderline_id
,min(convert_timezone('America/Los_Angeles', r.created_at)::date) as refund_date
,sum(ifnull(olr.subtotal, 0)) as orderline_refund_price
,sum(ifnull(olr.total_tax, 0)) as orderline_refund_taxes
from {{ source('shopify_source', 'refund') }} as r
left join {{ source('shopify_source', 'order_line_refund') }} as olr
  on r.id = olr.refund_id
where olr.order_line_id is not null
group by r.order_id, olr.order_line_id
))

select *
from orderline_refunds
