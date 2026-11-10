{{ config(
  materialized='table',
  
  ) }}
select * 
from {{ ref('tests_dash_stg02_with_variant_arr') }}
