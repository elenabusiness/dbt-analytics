{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"
}

with shopify_customer_ids_emails_phones as (
select distinct
-- split(customer_id, '_')[OFFSET(0)] customer_id
customer_id_original
,email
,phone
from {{ ref('customers_rebill_stats_stg01') }}
)

select * from shopify_customer_ids_emails_phones
