{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with order_lines_enhanced as (
select *
from
(select *
,orderline_paid_by_customer - orderline_total_refund - (orderline_tax - orderline_refund_taxes) - orderline_dispute_amount as orderline_revenue
,orderline_paid_by_customer - orderline_tax as orderline_revenue_before_refunds

from
(select * exclude (orderline_refund_date, order_adjustment_refund_date)
,orderline_price - orderline_discount + orderline_tax + orderline_shipping_cost as orderline_paid_by_customer
,orderline_refund_price + orderline_refund_taxes + orderline_adjustments_tax + orderline_adjustments_refund as orderline_total_refund
,least(orderline_refund_date, order_adjustment_refund_date) as refund_date
from
(select order_lines.* exclude (dog_weight_from_product, dog_size)
,0.3 + 0.0215 * iff(source_name in ('shopify_installments', 'shopify_payments'), orderline_price, 0) as orderline_transaction_fee
,ifnull(cast(cogs.cogs as float), 0) * order_lines.orderline_quantity as orderline_cogs
,ifnull(fulfillment_cost.order_fulfillment_cost, 0) * orderline_share_in_order as orderline_fulfillment_cost
,ifnull(dog_weight.dog_weight_category, coalesce(order_lines.dog_weight_from_product, order_lines.dog_size)) as dog_weight_from_product
,ifnull(order_lines.order_id = orderline_refunds.order_id or order_lines.order_id = order_adjustments.order_id, false) as order_has_refund
,orderline_refunds.refund_date as orderline_refund_date
,ifnull(orderline_refunds.orderline_refund_price, 0) as orderline_refund_price
,ifnull(orderline_refunds.orderline_refund_taxes, 0) as orderline_refund_taxes
,order_adjustments.refund_date as order_adjustment_refund_date
,ifnull(order_adjustments.order_adjustments_tax, 0) * orderline_share_in_order as orderline_adjustments_tax
,ifnull(order_adjustments_ref, 0) * orderline_share_in_order as orderline_adjustments_refund
,ifnull(order_lines.order_id = disputes.order_id, false) as order_has_dispute
,ifnull(disputes.dispute_amount, 0) * orderline_share_in_order as orderline_dispute_amount
from {{ ref('stg050_orderline_varian_vs_klaviyo') }} as order_lines
left join {{ ref('stg055_cogs_clean') }} as cogs
  on order_lines.sku = cogs.sku
left join {{ ref('stg051_fulfillment_cost_order_level_clean') }} as fulfillment_cost
  on order_lines.order_id = cast(fulfillment_cost.order_id as string)
left join {{ ref('stg056_dog_weight_clean') }} as dog_weight
  on ifnull(order_lines.dog_weight_from_product, order_lines.dog_size) = dog_weight.dog_weight_raw
left join {{ ref('stg053_refunds_orderlines') }} as orderline_refunds
  on order_lines.order_id = orderline_refunds.order_id and order_lines.orderline_id = orderline_refunds.orderline_id
left join {{ ref('stg052_refunds_order_adjustments') }} as order_adjustments
  on order_lines.order_id = order_adjustments.order_id
left join {{ ref('stg057_disputes_order_level') }} as disputes
  on order_lines.order_id = disputes.order_id
)))
)

select *
,first_value(order_date) over (partition by customer_id order by order_timestamp asc) as customer_first_order_date
from order_lines_enhanced