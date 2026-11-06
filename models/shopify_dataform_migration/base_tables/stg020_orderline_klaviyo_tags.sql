{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select *
from {{ ref('stg010_orderline_clean') }}