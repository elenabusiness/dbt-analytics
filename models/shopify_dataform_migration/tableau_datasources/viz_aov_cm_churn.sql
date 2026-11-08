{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
select * from {{ ref('aov_cm_churn') }} 