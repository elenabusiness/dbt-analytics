{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with customer_transformations as (
select 
*
,iff(is_first_order, max_expected_next_order_date_order_level<=current_date() or customer_second_order_date is not null or (customer_second_order_date is null and sub_status = 'cancelled'),null) time_window_for_second_order_complete
,iff(is_second_order, max_expected_next_order_date_order_level<=current_date() or customer_third_order_date is not null  or (customer_third_order_date is null and sub_status = 'cancelled'),null) time_window_for_third_order_complete
,iff(is_first_order,max_expected_next_order_date_order_level is null and customer_second_order_date is null,null) is_second_order_date_unknown
,iff(is_second_order,max_expected_next_order_date_order_level is null and customer_third_order_date is null,null) is_third_order_date_unknown
,iff(is_second_order,not order_has_refund,null) is_second_order_success
,iff(is_third_order,not order_has_refund,null) is_third_order_success
from (
select *
,iff(is_first_order,DATEDIFF(day, order_date, coalesce(date_positive_cm_reached_by_customer_by_sub_frequency,date_positive_cm_reached_by_sub_frequency)),null) days_to_positive_cm
from (
select *
,min(iff(running_cm_by_customer_by_sub_frequency>0,order_date,null)) over (partition by customer_id, sub_frequency) date_positive_cm_reached_by_customer_by_sub_frequency
,min(iff(running_cm_by_date_by_sub_frequency>0,order_date,null)) over (partition by customer_first_order_date,sub_frequency) date_positive_cm_reached_by_sub_frequency
,iff(is_first_order,customer_second_order_date is null and ((is_sub and sub_status = 'cancelled') or (not (is_sub) and expected_next_order_date_orderline_level<=current_date)),null) is_churned_after_first_order
,iff(is_second_order, customer_third_order_date is null and ((is_sub and sub_status = 'cancelled') or (not (is_sub) and expected_next_order_date_orderline_level<=current_date)),null) is_churned_after_second_order
from (
select * 
,count(distinct order_id) over (partition by customer_id) >1 customer_reached_first_billing
,max(is_sub) over (partition by customer_id) customer_has_subscription
,first_value(iff(is_sub,order_date,null) ignore nulls) over(partition by customer_id order by order_timestamp asc) customer_first_sub_order_date
,DATEDIFF(day, customer_first_order_date, order_date) days_after_first_order
,sum(orderline_cm) over (partition by customer_id, sub_frequency order by order_timestamp asc, orderline_cm asc) running_cm_by_customer_by_sub_frequency
,sum(orderline_cm) over (partition by customer_id, sub_frequency) total_cm_by_customer_by_sub_frequency
,sum(orderline_cm) over (partition by customer_first_order_date,sub_frequency order by order_timestamp asc,orderline_cm asc) running_cm_by_date_by_sub_frequency
,max(iff(is_second_order,order_date,null)) over (partition by customer_id) customer_second_order_date
,max(iff(is_third_order,order_date,null)) over (partition by customer_id) customer_third_order_date
from {{ ref('stg140_orderline_sub_transformations') }} 
)))
)


select * from customer_transformations