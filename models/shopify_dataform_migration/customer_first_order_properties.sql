{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

  
  
  
select * EXCLUDE (sub_frequency_group_customer,sub_type,dog_weight_from_product,sub_frequency_group_subscriber,source_type,source_url
,variant_title,sub_frequency)
,NULLIF(sub_frequency_group_customer, '') sub_frequency_group
,NULLIF(sub_type, '') sub_type
,NULLIF(dog_weight_from_product, '') dog_weight_from_product
,NULLIF(sub_frequency_group_subscriber, '') sub_frequency_group_subscriber
,NULLIF(source_type, '') source_type
,NULLIF(source_url, '') source_url
,NULLIF(variant_title, '') variant_title
,NULLIF(sub_frequency, '') sub_frequency

from
(select distinct * EXCLUDE (
    sub_frequency_group_arr_customer
    ,sub_type_arr
    ,dog_weight_from_product_arr
    ,sub_frequency_group_arr_subscriber
    ,source_type_agg
    ,source_url_arr
    ,variant_title_arr
    ,sub_frequency_arr
    ,tests_arr)
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(sub_frequency_group_arr_customer))), ' | ') sub_frequency_group_customer
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(sub_type_arr))), ' | ') sub_type
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(dog_weight_from_product_arr))), ' | ') dog_weight_from_product
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(sub_frequency_group_arr_subscriber))), ' | ') sub_frequency_group_subscriber
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(source_type_agg))), ' | ') source_type
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(source_url_arr))), ' | ') source_url
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(variant_title_arr))), ' | ') variant_title
,ARRAY_TO_STRING(ARRAY_SORT(ARRAY_DISTINCT(ARRAY_COMPACT(sub_frequency_arr))), ' | ') sub_frequency

from
(select 
customer_id, customer_first_order_date
,array_agg(iff(is_first_order,sub_frequency_group,null)) over (partition by customer_id) sub_frequency_group_arr_customer
,array_agg(iff(is_first_order,source_name,null)) over (partition by customer_id) source_type_agg
,array_agg(iff(is_first_order_with_sub,sub_frequency_group,null)) over (partition by customer_id) sub_frequency_group_arr_subscriber
,first_value(customer_reached_first_billing ignore nulls) over (partition by customer_id order by order_timestamp asc) customer_reached_first_billing
,first_value(is_retained_customer ignore nulls) over (partition by customer_id order by order_timestamp asc) is_retained_customer
,first_value(iff(is_first_order,tests_arr,null)) over (partition by customer_id order by order_timestamp asc) tests_arr
-- ,first_value(iff(is_first_order,test_variant,null)) over (partition by customer_id order by order_timestamp asc) test_variant 
,array_agg(iff(is_first_order,sub_type,null)) over (partition by customer_id) sub_type_arr
,array_agg(iff(is_first_order,dog_weight_from_product,null)) over (partition by customer_id) dog_weight_from_product_arr
,array_agg(iff(is_first_order,orderline_variant_title,null)) over (partition by customer_id) variant_title_arr
,array_agg(iff(is_first_order,sub_frequency,null)) over (partition by customer_id) sub_frequency_arr
,max(iff(is_first_order, is_sub,null)) over (partition by customer_id) is_subscriber
,max(time_window_for_second_order_complete) over (partition by customer_id) time_window_for_second_order_complete
,max(is_second_order_success) over (partition by customer_id) is_second_order_success
,min(is_churned_after_first_order) over (partition by customer_id) is_churned_after_first_order
,max(time_window_for_third_order_complete) over (partition by customer_id) time_window_for_third_order_complete
,max(is_third_order_success)  over (partition by customer_id) is_third_order_success
,min(is_churned_after_second_order) over (partition by customer_id) is_churned_after_second_order
,array_agg(iff(is_first_order,source_url,null)) over (partition by customer_id) source_url_arr
FROM {{ ref('base_orderlines') }}
)
)
