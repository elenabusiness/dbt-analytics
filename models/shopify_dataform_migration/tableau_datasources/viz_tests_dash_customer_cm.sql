{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
select * 
from {{ ref('tests_dash_stg02_with_variant_arr') }}
