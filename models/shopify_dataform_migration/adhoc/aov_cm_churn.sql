{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "adhoc"}

with base_table as (
select order_date, customer_id, order_id, order_name, sub_id, is_sub, sub_frequency, is_sub_churn_after_one_payment, is_first_order, days_after_first_order, orderline_revenue order_revenue, orderline_cogs order_cogs, orderline_fulfillment_cost order_fulfillment_cost, orderline_transaction_fee order_transaction_fee, orderline_price order_price
from {{ ref('base_orderlines') }} 
where is_sub
union all 
select order_date, customer_id, order_id, order_name, null sub_id, is_sub, sub_frequency, null is_sub_churn_after_one_payment, is_first_order, days_after_first_order, orderline_revenue, orderline_cogs, orderline_fulfillment_cost, orderline_transaction_fee, orderline_price
from {{ ref('base_orderlines') }} 
where not is_sub 
)

, base_table_with_order_types as (
select * 
,not max(is_sub) over (partition by order_id) is_onetime_order
,min(is_sub) over (partition by order_id) is_sub_order
,max(is_sub) over (partition by order_id) and not min(is_sub) over (partition by order_id) is_mixed_order
from base_table
)

, daily_stats as (
select
order_date
,count (distinct order_id) orders
,count(distinct if (is_onetime_order, order_id, null)) onetime_orders
,count(distinct if (is_sub_order, order_id, null)) subscription_orders
,count(distinct if (is_mixed_order, order_id, null)) mixed_orders

,sum(order_price) order_gross_sales
,sum(if (is_onetime_order, order_price, null)) onetime_order_gross_sales
,sum(if (is_sub_order, order_price, null)) subscription_order_gross_sales
,sum(if (is_mixed_order, order_price, null)) mixed_order_gross_sales


,sum(order_revenue) order_revenue
,sum(if (is_onetime_order, order_revenue, null)) onetime_order_revenue
,sum(if (is_sub_order, order_revenue, null)) subscription_order_revenue
,sum(if (is_mixed_order, order_revenue, null)) mixed_order_revenue

,count (distinct customer_id) customers
,count (distinct if(is_first_order,customer_id,null)) new_customers
,count (distinct if(not is_first_order,customer_id,null)) returning_customers
,sum(if (is_first_order, order_revenue, null)) new_customers_order_revenue
,sum(if (not is_first_order, order_revenue, null)) returning_customers_order_revenue

,count(distinct if(is_sub and is_first_order, sub_id, null)) new_subscriptions
,count(distinct if(is_sub and is_first_order and is_sub_churn_after_one_payment, sub_id, null)) new_subscriptions_churn_after_one_payment

,sum(customer_order_revenue_first_60_days) new_customer_order_revenue_first_60_days
,sum(customer_order_cogs_first_60_days) new_customer_order_cogs_first_60_days
,sum(customer_order_fulfillment_cost_first_60_days) new_customer_order_fulfillment_cost_first_60_days
,sum(customer_order_transaction_fee_first_60_days) new_customer_order_transaction_fee_first_60_days


from (select *

,if(is_first_order and row_number() over (partition by order_id order by is_sub,sub_frequency,is_first_order,days_after_first_order,order_revenue,order_cogs,Order_fulfillment_cost,order_transaction_fee) = 1
,sum(if(days_after_first_order<=60, order_revenue, 0)) over (partition by customer_id) 
,null
) customer_order_revenue_first_60_days

,if(is_first_order and row_number() over (partition by order_id order by is_sub,sub_frequency,is_first_order,days_after_first_order,order_revenue,order_cogs,Order_fulfillment_cost,order_transaction_fee) = 1
,sum(if(days_after_first_order<=60, order_cogs, 0)) over (partition by customer_id) 
,null
) customer_order_cogs_first_60_days

,if(is_first_order and row_number() over (partition by order_id order by is_sub,sub_frequency,is_first_order,days_after_first_order,order_revenue,order_cogs,Order_fulfillment_cost,order_transaction_fee) = 1
,sum(if(days_after_first_order<=60, Order_fulfillment_cost, 0)) over (partition by customer_id) 
,null
) customer_order_fulfillment_cost_first_60_days

,if(is_first_order and row_number() over (partition by order_id order by is_sub,sub_frequency,is_first_order,days_after_first_order,order_revenue,order_cogs,Order_fulfillment_cost,order_transaction_fee) = 1
,sum(if(days_after_first_order<=60, order_transaction_fee, 0)) over (partition by customer_id) 
,null
) customer_order_transaction_fee_first_60_days

from base_table_with_order_types)
group by order_date
)

,ads_spend_clean as 
(select 
date,
sum(cost) cost
from `stitch-data-296516.wf_dw.wf_ad_spent`
group by date
)

,daily_stats_with_marketing as(
select * from 
(select daily_stats.*
,ads_spend_clean.cost marketing_cost
from daily_stats
left join ads_spend_clean
on daily_stats.order_date = ads_spend_clean.date
))



select * from daily_stats_with_marketing
