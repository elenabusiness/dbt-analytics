{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with tests_arr as (
select 
customer_id
,first_value(iff(is_first_order,tests_arr,null)) over (partition by customer_id order by order_timestamp asc) tests_arr
from {{ ref('base_orderlines') }}
qualify row_number() over (partition by customer_id order by order_timestamp asc) = 1
)


select first_order_props.*, tests_arr.tests_arr
from {{ ref('customer_first_order_properties') }} first_order_props
left join tests_arr
on first_order_props.customer_id = tests_arr.customer_id
