{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "visualisation_preps"
}

with base_metrics as (
select 
customer_id
,dog_weight_from_product
,customer_first_order_date first_order_date
,is_first_order
,source_type
,sub_frequency_group
,sub_type
-- ,test_no vwo_test_no
-- ,test_variant vwo_variant
,orderline_cm order_cm
,orderline_cm_less_cac order_cm_less_cac
,age
,body_type
,breed
,dog_weight_from_questionnaire
,has_joint_issues
,days15_after_first_order
,is_churned_after_first_order
,is_churned_after_second_order
,is_second_order
,is_second_order_date_unknown
,is_second_order_success
,is_third_order
,is_third_order_date_unknown
,is_third_order_success
,time_window_for_second_order_complete
,time_window_for_third_order_complete
,orderline_paid_by_customer order_paid_by_customer
,tests.test_name vwo_test_no
,if(tests.test_variant = '1', 'Control',tests.test_variant) vwo_variant
from {{ ref('customer_ltv_cohort_order_line_level') }}
left join unnest(tests_arr) tests
)


select * 
from base_metrics
where vwo_test_no is not null