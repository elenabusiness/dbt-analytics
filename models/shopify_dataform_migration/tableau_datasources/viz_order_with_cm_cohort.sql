{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
select *  
from {{ ref('orders_with_cm_cohort') }} orders
