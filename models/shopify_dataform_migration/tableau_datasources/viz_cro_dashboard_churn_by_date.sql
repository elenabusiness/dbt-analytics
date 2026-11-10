{{ config(
  materialized='table',
  
  ) }}
select 
*
,DATEDIFF(day, customer_first_order_date, churn_date)+1 days_to_churn
from
(select distinct
customer_id
,customer_first_order_date
,test_no vwo_test_no
,iff(test_variant = '1', 'Control',test_variant) vwo_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product,variant_title
,max(churn_date) over (partition by customer_id) churn_date
from {{ ref('cro_dashboard_stg11_customer_churn') }}
where churn_date is not null and test_no is not null and not(is_retained_customer))