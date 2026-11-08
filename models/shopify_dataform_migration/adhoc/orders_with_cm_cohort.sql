{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with base_table as
(
select 
date_trunc (month,order_date) month
,order_id, order_date, order_timestamp, customer_id, is_first_order, orderline_price gross_sales,orderline_transaction_fee transaction_fee, orderline_revenue revenue, orderline_cogs cogs, orderline_fulfillment_cost fulfillment_cost
,not max(is_sub) over (partition by order_id) is_onetime_order
,min(is_sub) over (partition by order_id) is_subscription_order
,max(is_sub) over (partition by order_id) and not min(is_sub) over (partition by order_id) is_mixed_order
,case
    when not max(is_sub) over (partition by order_id) then 'Onetime Orders'
    when min(is_sub) over (partition by order_id) then 'Subscription Orders'
    when max(is_sub) over (partition by order_id) and not min(is_sub) over (partition by order_id) then 'Mixed Orders'
end order_type

,is_first_order is_new_customer
,not is_first_order is_returning_customer
,iff(is_first_order,'New Customers','Returning Customers') customer_type

,days_after_first_order
from {{ ref('base_orderlines') }} orders
where customer_id is not null

)

, base_table_order_agg as(
select 
month
,order_id
,order_date
,order_timestamp
,customer_id
,is_first_order
,max(days_after_first_order) days_after_first_order
,sum(gross_sales) order_gross_sales
,sum(transaction_fee) order_transaction_fee
,sum(revenue) order_revenue
,sum(cogs) order_cogs
,sum(fulfillment_cost) order_fulfillment_cost
,max(is_onetime_order) is_onetime_order
,max(is_subscription_order) is_subscription_order
,max(is_mixed_order) is_mixed_order
,order_type
,max(is_new_customer) is_new_customer
,max(is_returning_customer) is_returning_customer
,customer_type

from base_table
group by 
month
,order_id
,order_date
,order_timestamp
,customer_id
,is_first_order
,order_type
,customer_type
)


, base_table_with_marketing_spend as (
select orders.* 
,ifnull(DIV0(iff(is_first_order,ads_spend.cost,null),count(distinct iff(is_first_order,customer_id,null)) over (partition by order_date)),0) marketing_spend_per_new_customer
from base_table_order_agg orders
left join {{ ref('stg101_marketing_spend_by_date') }} ads_spend
on orders.order_date = ads_spend.date
)

, base_table_with_cm as (
select * 
,customer_order_revenue_first_60_days-customer_order_cogs_first_60_days-customer_order_fulfillment_cost_first_60_days-customer_order_transaction_fee_first_60_days-marketing_spend_per_new_customer customer_cm_first_60_days
,order_revenue-order_cogs-order_fulfillment_cost-order_transaction_fee-marketing_spend_per_new_customer order_cm
,order_revenue-marketing_spend_per_new_customer order_revenue_less_marketing

,first_value(order_date) over (partition by customer_id order by order_timestamp asc) first_order_date

from
(select *
,iff(
    is_first_order
    ,sum(iff(days_after_first_order<=60, order_revenue, 0)) over (partition by customer_id)
    ,null
) customer_order_revenue_first_60_days

,iff(
    is_first_order
    ,sum(iff(days_after_first_order<=60, order_cogs, 0)) over (partition by customer_id)
    ,null
) customer_order_cogs_first_60_days

,iff(
    is_first_order
    ,sum(iff(days_after_first_order<=60, Order_fulfillment_cost, 0)) over (partition by customer_id)
    ,null
) customer_order_fulfillment_cost_first_60_days

,iff(
    is_first_order
    ,sum(iff(days_after_first_order<=60, order_transaction_fee, 0)) over (partition by customer_id)
    ,null
) customer_order_transaction_fee_first_60_days
from base_table_with_marketing_spend)
)

, cohort as (
select * EXCLUDE (days_after_first_order)
,DATEDIFF(month, first_order_date, order_date) months_after_first_order
,DATEDIFF(week, first_order_date, order_date) weeks_after_first_order
,DATEDIFF(day, first_order_date, order_date) days_after_first_order
from base_table_with_cm
)



select * from cohort