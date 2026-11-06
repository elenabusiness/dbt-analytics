{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}

select 
age
,body_type
,breed
,customer_first_order_date
,customer_id
,dog_weight_from_product
,dog_weight_from_questionnaire
,has_joint_issues
,is_customer_active
,is_last_day_of_15day_interval
,label
,source_type
,test_no vwo_test_no
,if(test_variant = '1', 'Control',test_variant) vwo_variant
,sub_frequency_group
,sub_type

from {{ ref('cro_dashboard_stg12_customer_churn_with_active_status_forecast') }}
where customer_first_order_date >='2023-01-01' and is_last_day_of_15day_interval 
