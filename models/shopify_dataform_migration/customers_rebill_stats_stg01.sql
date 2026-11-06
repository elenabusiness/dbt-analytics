{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"
}

with orderlines_with_first_order_props as
(select 
order_rank
,order_id
,order_date
,orderlines.customer_id
,orderlines.customer_id_original
,email,phone
,is_next_order_completed
,is_order_success
,true is_order
,order_has_refund
,is_customer_churned_after_this_order
,first_value (order_date) over (partition by orderlines.customer_id order by order_date asc) first_order_date
,first_order_props.sub_frequency_group
-- ,first_order_props.test_no, first_order_props.test_variant
,first_order_props.offer_tubs,first_order_props.dog_weight_from_product
,orderline_cm
,orderline_marketing_cost
from {{ ref('base_orderlines') }} orderlines
left join {{ ref('customer_first_order_properties_with_offer_tubs') }} first_order_props
on orderlines.customer_id = first_order_props.customer_id)


,orders as (
select * except(orderline_cm,orderline_marketing_cost)
,date_trunc (first_order_date,month) cohort_month
,sum(orderline_cm) order_cm
,sum(orderline_marketing_cost) order_marketing_cost
from orderlines_with_first_order_props
group by order_rank,order_id,order_date,customer_id,customer_id_original,email,phone,
is_next_order_completed,is_order_success,is_order,order_has_refund,is_customer_churned_after_this_order,first_order_date,sub_frequency_group
-- ,test_no,test_variant
,offer_tubs,dog_weight_from_product
)

, orders_adjusted as (
select 
cohort_month
,first_order_date
,customer_id
,customer_id_original
,email,phone
,lead(order_date) over (partition by customer_id order by order_rank asc) order_date
,order_rank+1 order_rank
,is_next_order_completed is_order_complete
,ifnull(lead(is_order_success) over (partition by customer_id order by order_rank asc),false) is_order_success
,ifnull(lead(is_order) over (partition by customer_id order by order_rank asc),false) is_order_happened
,lead(order_has_refund) over (partition by customer_id order by order_rank asc) order_has_refund
,is_customer_churned_after_this_order is_customer_churned_before_this_order
,sub_frequency_group
-- ,test_no, test_variant
,offer_tubs,dog_weight_from_product
,lead(order_cm) over (partition by customer_id order by order_rank asc) order_cm
from orders
)

, sub_orders_with_first_orders_added as(
select 
cohort_month
,customer_id
,customer_id_original
,email,phone
,first_order_date
,order_rank
,is_order_complete
,is_order_success
,is_order_happened
,order_has_refund
,is_customer_churned_before_this_order
,sub_frequency_group
-- ,test_no, test_variant
,offer_tubs,dog_weight_from_product
,order_cm
,0 order_marketing_cost
from orders_adjusted
union all
select 
cohort_month
,customer_id
,customer_id_original
,email,phone
,first_order_date
,1 order_rank
,true is_order_complete
,is_order_success
,is_order
,order_has_refund
,false is_customer_churned_before_this_order
,sub_frequency_group
-- ,test_no, test_variant
,offer_tubs,dog_weight_from_product
,order_cm
,order_marketing_cost
from orders
where order_rank = 1
)



select * 
from sub_orders_with_first_orders_added