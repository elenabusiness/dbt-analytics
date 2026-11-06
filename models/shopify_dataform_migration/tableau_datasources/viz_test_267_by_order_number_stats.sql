{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}

with test_267_customers as (
select distinct
customer_id
from
(select 
customer_id,tests
from {{ ref('customer_first_order_properties_with_offer_tubs') }}
left join unnest(tests_arr) tests)
where tests.test_name = 'VWO - 267' and tests.test_variant = '2'
)

,sub_orders_test_267 as (
select rebill_stats.*
from {{ ref('customers_rebill_stats_stg01') }} rebill_stats
join test_267_customers
on rebill_stats.customer_id = test_267_customers.customer_id
)

,sub_orders_agg as (
select
dog_weight_from_product,offer_tubs
,order_rank
,count(distinct customer_id) cohort_size
,count(distinct if(is_order_complete,customer_id,null)) customers_with_order_complete
,count(distinct if(is_order_happened,customer_id,null)) customers_with_orders
,count(distinct if(is_order_success,customer_id,null)) customers_with_order_success
,count(distinct if(order_has_refund,customer_id,null)) customers_with_order_refunded
,count(distinct if(is_customer_churned_before_this_order,customer_id,null)) customers_churned_after_this_order
,sum(order_cm) cm
,sum(order_marketing_cost) marketing_cost
from sub_orders_test_267
group by
dog_weight_from_product,offer_tubs,order_rank
)


select
* except(cm,marketing_cost)
,safe_divide(marketing_cost,cohort_size) cac
,ifnull(safe_divide(cm,customers_with_order_success),0) avg_cm
,cm
,sum(cm) over (partition by dog_weight_from_product,offer_tubs order by order_rank asc) cm_running
from sub_orders_agg