{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with base as 
(select orderlines.* EXCLUDE (
days_after_first_order
-- ,test_no,test_variant,
,tests_arr
,orderline_variant_title,customer_reached_first_billing,is_retained_customer,time_window_for_second_order_complete,is_second_order_success
,is_churned_after_first_order,time_window_for_third_order_complete,is_third_order_success,is_churned_after_second_order,source_url,sub_frequency_group,sub_type,dog_weight_from_product
,source_name,sub_frequency)
-- ,orderlines.test_no vwo_test_original
-- ,orderlines.test_variant vwo_variant_original
,orderlines.tests_arr tests_arr_original
,firt_order_props.* EXCLUDE (customer_id, customer_first_order_date)
FROM {{ ref('base_orderlines') }} orderlines
left join {{ ref('customer_first_order_properties_with_tests_arr') }} firt_order_props
on orderlines.customer_id = firt_order_props.customer_id
)


select * 
,iff(days_after_first_order=0,'0',concat(div0(days_after_first_order,7)*7+1,'-',div0(days_after_first_order,7)*7+7)) days_interval
,div0(days_after_first_order,7) days7_after_first_order
from
(select * 
,DATEDIFF(month, customer_first_order_date, order_date) months_after_first_order
,DATEDIFF(week, customer_first_order_date, order_date) weeks_after_first_order
,DATEDIFF(day, customer_first_order_date, order_date) days_after_first_order
,floor(DIV0(DATEDIFF(day, customer_first_order_date, order_date),15)) days15_after_first_order
from base
)
