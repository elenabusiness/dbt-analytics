{{ config(
  materialized='table',
  
  ) }}
select *  
from {{ ref('orders_with_cm_cohort') }} orders
