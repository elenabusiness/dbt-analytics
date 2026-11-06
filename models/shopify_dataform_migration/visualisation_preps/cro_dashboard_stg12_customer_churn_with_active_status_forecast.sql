{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "visualisation_preps"
}

with table_1 as (
select
*
,min(date) over (partition by test_no) test_start_date
from
(select 
customer_id
,date
,is_customer_active
,customer_first_order_date
,test_no
,test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product, dog_weight_from_questionnaire, age, body_type, breed, has_joint_issues,variant_title,fpv7discount,sub_frequency
from {{ ref('cro_dashboard_stg11_customer_churn') }} 
)
)
, table_2 as (
select
*
,date_diff(current_date, test_start_date,day) days_test_running 
,date_diff(current_date,customer_first_order_date,day) days_this_customer_in_test
from table_1
where date = current_date and is_customer_active
)

, table_3 as(
select 
customer_id, date, true is_customer_active, customer_first_order_date, test_no, test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product, dog_weight_from_questionnaire, age, body_type, breed, has_joint_issues,variant_title,fpv7discount,sub_frequency
from table_2
left join unnest(generate_date_array (date_add(current_date, interval 1 day),date_add(current_date, interval days_test_running-days_this_customer_in_test day))) date on true 
)

,table_4 as
(select 
customer_id
,date
,is_customer_active
,customer_first_order_date
,test_no
,test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product, dog_weight_from_questionnaire, age, body_type, breed, has_joint_issues,variant_title,fpv7discount,sub_frequency
from table_1

union all
select 
customer_id
,date
,is_customer_active
,customer_first_order_date
,test_no
,test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product, dog_weight_from_questionnaire, age, body_type, breed, has_joint_issues,variant_title,fpv7discount,sub_frequency
from table_3
)

,table_5 as (
select * 
,date_diff(date,customer_first_order_date,day) days_after_first_order
,floor(safe_divide(date_diff(date,customer_first_order_date,day),15)) days15_after_first_order
,

date = max(date) over(partition by customer_id) or 
mod(date_diff(date, customer_first_order_date, day)+1, 15) = 0 is_last_day_of_15day_interval

from table_4

)

select * 
,if (days_after_first_order = 0, 'Day 1',concat('Day ',cast(15*(round(days15_after_first_order+1,0)) as string))) label
from table_5
