{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

  
  
  
select * except(sub_frequency_group_customer,sub_type,dog_weight_from_product,sub_frequency_group_subscriber,source_type,source_url,dog_weight_from_questionnaire
,age,breed,body_type,has_joint_issues,fpv7discount_klaviyo,variant_title,sub_frequency)
,if (sub_frequency_group_customer = '',null,sub_frequency_group_customer) sub_frequency_group
,if (sub_type = '',null,sub_type) sub_type
,if (dog_weight_from_product = '',null,dog_weight_from_product) dog_weight_from_product
,if (dog_weight_from_questionnaire = '',null,dog_weight_from_questionnaire) dog_weight_from_questionnaire
,if (age = '',null,age) age
,if (breed = '',null,breed) breed
,if (body_type = '',null,body_type) body_type
,if (has_joint_issues = '',null,has_joint_issues) has_joint_issues
,if (sub_frequency_group_subscriber = '',null,sub_frequency_group_subscriber) sub_frequency_group_subscriber
,if (source_type = '',null,source_type) source_type
,if (source_url = '',null,source_url) source_url
,if (fpv7discount_klaviyo = '',null,fpv7discount_klaviyo) fpv7discount
,if (variant_title = '',null,variant_title) variant_title
,if (sub_frequency = '',null,sub_frequency) sub_frequency

from
(select distinct * except(
    sub_frequency_group_arr_customer
    ,sub_type_arr
    ,dog_weight_from_product_arr
    ,sub_frequency_group_arr_subscriber
    ,source_type_agg
    ,source_url_arr
    ,dog_weight_from_questionnaire_arr
    ,age_arr,breed_arr,body_type_arr,has_joint_issues_arr
    ,fpv7discount_klaviyo_arr
    ,variant_title_arr
    ,sub_frequency_arr
    ,tests_arr)
,array_to_string(array(select distinct sub_frequency_group_customer from unnest(sub_frequency_group_arr_customer) sub_frequency_group_customer where sub_frequency_group_customer is not null order by sub_frequency_group_customer),' | ' ) sub_frequency_group_customer
,array_to_string(array(select distinct sub_type from unnest(sub_type_arr) sub_type where sub_type is not null order by sub_type),' | ' ) sub_type
,array_to_string(array(select distinct dog_weight_from_product from unnest(dog_weight_from_product_arr) dog_weight_from_product where dog_weight_from_product is not null order by dog_weight_from_product),' | ' ) dog_weight_from_product
,array_to_string(array(select distinct dog_weight_from_questionnaire from unnest(dog_weight_from_questionnaire_arr) dog_weight_from_questionnaire where dog_weight_from_questionnaire is not null order by dog_weight_from_questionnaire),' | ' ) dog_weight_from_questionnaire
,array_to_string(array(select distinct age from unnest(age_arr) age where age is not null order by age),' | ' ) age
,array_to_string(array(select distinct breed from unnest(breed_arr) breed where breed is not null order by breed),' | ' ) breed
,array_to_string(array(select distinct body_type from unnest(body_type_arr) body_type where body_type is not null order by body_type),' | ' ) body_type
,array_to_string(array(select distinct has_joint_issues from unnest(has_joint_issues_arr) has_joint_issues where has_joint_issues is not null order by has_joint_issues),' | ' ) has_joint_issues
,array_to_string(array(select distinct sub_frequency_group_subscriber from unnest(sub_frequency_group_arr_subscriber) sub_frequency_group_subscriber where sub_frequency_group_subscriber is not null order by sub_frequency_group_subscriber),' | ' ) sub_frequency_group_subscriber
,array_to_string(array(select distinct source_type from unnest(source_type_agg) source_type where source_type is not null order by source_type),' | ' ) source_type
,array_to_string(array(select distinct source_url from unnest(source_url_arr) source_url where source_url is not null order by source_url),' | ' ) source_url
,array_to_string(array(select distinct fpv7discount_klaviyo from unnest(fpv7discount_klaviyo_arr) fpv7discount_klaviyo where fpv7discount_klaviyo is not null order by fpv7discount_klaviyo),' | ' ) fpv7discount_klaviyo
,array_to_string(array(select distinct variant_title from unnest(variant_title_arr) variant_title where variant_title is not null order by variant_title),' | ' ) variant_title
,array_to_string(array(select distinct sub_frequency from unnest(sub_frequency_arr) sub_frequency where sub_frequency is not null order by sub_frequency),' | ' ) sub_frequency

from
(select 
customer_id, customer_first_order_date
,array_agg(if(is_first_order,sub_frequency_group,null)) over (partition by customer_id) sub_frequency_group_arr_customer
,array_agg(if(is_first_order,source_type,null)) over (partition by customer_id) source_type_agg
,array_agg(if(is_first_order_with_sub,sub_frequency_group,null)) over (partition by customer_id) sub_frequency_group_arr_subscriber
,first_value(customer_reached_first_billing ignore nulls) over (partition by customer_id order by order_timestamp asc) customer_reached_first_billing
,first_value(is_retained_customer ignore nulls) over (partition by customer_id order by order_timestamp asc) is_retained_customer
,first_value(if(is_first_order,tests_arr,null)) over (partition by customer_id order by order_timestamp asc) tests_arr
-- ,first_value(if(is_first_order,test_variant,null)) over (partition by customer_id order by order_timestamp asc) test_variant 
,array_agg(if(is_first_order,sub_type,null)) over (partition by customer_id) sub_type_arr
,array_agg(if(is_first_order,dog_weight_from_product,null)) over (partition by customer_id) dog_weight_from_product_arr
,array_agg(if(is_first_order,dog_weight_klaviyo_questionnaire,null)) over (partition by customer_id) dog_weight_from_questionnaire_arr
,array_agg(if(is_first_order,age_klaviyo_questionnaire,null)) over (partition by customer_id) age_arr
,array_agg(if(is_first_order,breed_klaviyo_questionnaire,null)) over (partition by customer_id) breed_arr
,array_agg(if(is_first_order,body_type_klaviyo_questionnaire,null)) over (partition by customer_id) body_type_arr
,array_agg(if(is_first_order,joint_issues_klaviyo_questionnaire,null)) over (partition by customer_id) has_joint_issues_arr
,array_agg(if(is_first_order,fpv7discount_klaviyo,null)) over (partition by customer_id) fpv7discount_klaviyo_arr
,array_agg(if(is_first_order,orderline_variant_title,null)) over (partition by customer_id) variant_title_arr
,array_agg(if(is_first_order,sub_frequency,null)) over (partition by customer_id) sub_frequency_arr
,max(if(is_first_order, is_sub,null)) over (partition by customer_id) is_subscriber
,max(time_window_for_second_order_complete) over (partition by customer_id) time_window_for_second_order_complete
,max(is_second_order_success) over (partition by customer_id) is_second_order_success
,min(is_churned_after_first_order) over (partition by customer_id) is_churned_after_first_order
,max(time_window_for_third_order_complete) over (partition by customer_id) time_window_for_third_order_complete
,max(is_third_order_success)  over (partition by customer_id) is_third_order_success
,min(is_churned_after_second_order) over (partition by customer_id) is_churned_after_second_order
,array_agg(if(is_first_order,source_url,null)) over (partition by customer_id) source_url_arr
FROM {{ ref('base_orderlines') }}
)
)
