{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
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
,sub_type, source_type, sub_frequency_group, dog_weight_from_product,variant_title,sub_frequency
from {{ ref('cro_dashboard_stg11_customer_churn') }} 
)
)
, table_2 as (
select
*
,DATEDIFF(day, test_start_date, current_date) days_test_running
,DATEDIFF(day, customer_first_order_date, current_date) days_this_customer_in_test
from table_1
where date = current_date and is_customer_active
)

, date_spine as (
select DATEADD(day, row_number() over (order by seq4()), current_date) as generated_date
from TABLE(GENERATOR(rowcount => 3650))
)

, table_3 as(
select
customer_id, d.generated_date as date, true is_customer_active, customer_first_order_date, test_no, test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product,variant_title,sub_frequency
from table_2
left join date_spine d
  on d.generated_date <= DATEADD(day, days_test_running - days_this_customer_in_test, current_date)
)

,table_4 as
(select 
customer_id
,date
,is_customer_active
,customer_first_order_date
,test_no
,test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product,variant_title,sub_frequency
from table_1

union all
select 
customer_id
,date
,is_customer_active
,customer_first_order_date
,test_no
,test_variant
,sub_type, source_type, sub_frequency_group, dog_weight_from_product,variant_title,sub_frequency
from table_3
)

,table_5 as (
select * 
,DATEDIFF(day, customer_first_order_date, date) days_after_first_order
,floor(DIV0(DATEDIFF(day, customer_first_order_date, date),15)) days15_after_first_order
,

date = max(date) over(partition by customer_id) or
mod(DATEDIFF(day, customer_first_order_date, date)+1, 15) = 0 is_last_day_of_15day_interval

from table_4

)

select * 
,iff(days_after_first_order = 0, 'Day 1',concat('Day ',cast(15*(round(days15_after_first_order+1,0)) as string))) label
from table_5
