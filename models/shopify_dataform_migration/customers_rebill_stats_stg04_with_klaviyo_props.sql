{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"
}


select 
orders.*
,klaviyo_props.* except(customer_id_original)
from {{ ref('customers_rebill_stats_stg01') }} orders
left join {{ ref('customers_rebill_stats_stg03_mapping_customer_id_to_klaviyo_props') }} klaviyo_props
on orders.customer_id_original = klaviyo_props.customer_id_original


