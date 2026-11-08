{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with cohort as 
(select
*
,DATEDIFF(month, customer_first_order_date, date) months_after_first_order
,DATEDIFF(week, customer_first_order_date, date) weeks_after_first_order
,DATEDIFF(day, customer_first_order_date, date) days_after_first_order
from
(select
customer_id_with_acquisition_rank customer_id
,date
,is_active_due_to_sub is_customer_active
,min(iff(is_active_due_to_sub,date,null)) over (partition by customer_id_with_acquisition_rank) customer_first_order_date
,is_last_day_of_month
from {{ ref('stg080_customer_status_by_date') }}
))


select cohort.* 
,firt_order_props.* EXCLUDE (customer_id,customer_first_order_date, sub_frequency_group,sub_frequency_group_subscriber
-- ,test_no, test_variant
)
-- ,test_no vwo_test_no
-- ,test_variant vwo_variant
,sub_frequency_group_subscriber sub_frequency_group
from cohort
left join {{ ref('customer_first_order_properties') }} firt_order_props
on cohort.customer_id = firt_order_props.customer_id
where days_after_first_order >=0