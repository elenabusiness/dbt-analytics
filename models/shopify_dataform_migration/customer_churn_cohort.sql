{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with first_order_props_added as (
select 
customer_status_by_date.customer_id_with_acquisition_rank customer_id
,customer_status_by_date.* EXCLUDE (customer_id, customer_id_with_acquisition_rank,customer_first_order_date)
,firt_order_props.* EXCLUDE (customer_id)
from {{ ref('stg080_customer_status_by_date') }} customer_status_by_date
left join {{ ref('customer_first_order_properties_with_tests_arr') }} firt_order_props
on customer_status_by_date.customer_id_with_acquisition_rank = firt_order_props.customer_id
)
, final as (
select 
*
,DATEDIFF(month, customer_first_order_date, date) months_after_first_order
,DATEDIFF(week, customer_first_order_date, date) weeks_after_first_order
,DATEDIFF(day, customer_first_order_date, date) days_after_first_order
,floor(DIV0(DATEDIFF(day, customer_first_order_date, date),15)) days15_after_first_order
from first_order_props_added
)

select * from final