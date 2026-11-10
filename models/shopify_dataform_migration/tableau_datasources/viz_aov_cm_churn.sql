{{ config(
  materialized='table',
  
  ) }}
select * from {{ ref('aov_cm_churn') }} 