{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "tableau_datasources"}

select *  
from {{ ref('orders_with_cm_cohort') }} orders
