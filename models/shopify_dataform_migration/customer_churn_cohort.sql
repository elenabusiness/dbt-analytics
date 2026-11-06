{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"
}

with first_order_props_added as (
select 
customer_status_by_date.customer_id_with_acquisition_rank customer_id
,customer_status_by_date.* except(customer_id, customer_id_with_acquisition_rank,customer_first_order_date)
,firt_order_props.* except (customer_id)
from {{ ref('stg080_customer_status_by_date') }} customer_status_by_date
left join {{ ref('customer_first_order_properties_with_tests_arr') }} firt_order_props
on customer_status_by_date.customer_id_with_acquisition_rank = firt_order_props.customer_id
)
, final as (
select 
*
,date_diff(date,customer_first_order_date, month) months_after_first_order
,date_diff(date,customer_first_order_date, week) weeks_after_first_order
,date_diff(date,customer_first_order_date, day) days_after_first_order
,floor(safe_divide(date_diff(date,customer_first_order_date,day),15)) days15_after_first_order
from first_order_props_added
)

select * from final