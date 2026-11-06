{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "tableau_datasources"}

select *
from {{ ref('customers_rebill_completion_and_success_rates') }} orderlines
where cohort_month>='2023-01-01'
