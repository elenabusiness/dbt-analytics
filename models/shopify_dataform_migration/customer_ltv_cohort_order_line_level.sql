{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"}

with base as 
(select orderlines.* except (
days_after_first_order,dog_weight_klaviyo_questionnaire
,age_klaviyo_questionnaire
,breed_klaviyo_questionnaire
,body_type_klaviyo_questionnaire
,joint_issues_klaviyo_questionnaire
,fpv7discount_klaviyo
-- ,test_no,test_variant,
,tests_arr
,orderline_variant_title,customer_reached_first_billing,is_retained_customer,time_window_for_second_order_complete,is_second_order_success
,is_churned_after_first_order,time_window_for_third_order_complete,is_third_order_success,is_churned_after_second_order,source_url,sub_frequency_group,sub_type,dog_weight_from_product
,source_type,sub_frequency)
-- ,orderlines.test_no vwo_test_original
-- ,orderlines.test_variant vwo_variant_original
,orderlines.tests_arr tests_arr_original
,firt_order_props.* except (customer_id, customer_first_order_date)
FROM {{ ref('base_orderlines') }} orderlines
left join {{ ref('customer_first_order_properties_with_tests_arr') }} firt_order_props
on orderlines.customer_id = firt_order_props.customer_id
)


select * 
,if(days_after_first_order=0,'0',concat(div(days_after_first_order,7)*7+1,'-',div(days_after_first_order,7)*7+7)) days_interval
,div(days_after_first_order,7) days7_after_first_order
from
(select * 
,date_diff(order_date,customer_first_order_date,month) months_after_first_order
,date_diff(order_date,customer_first_order_date,week) weeks_after_first_order
,date_diff(order_date,customer_first_order_date,day) days_after_first_order
,floor(safe_divide(date_diff(order_date,customer_first_order_date,day),15)) days15_after_first_order
from base
)
