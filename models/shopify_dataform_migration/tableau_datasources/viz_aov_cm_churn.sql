{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "tableau_datasources"}

select * from {{ ref('aov_cm_churn') }} 