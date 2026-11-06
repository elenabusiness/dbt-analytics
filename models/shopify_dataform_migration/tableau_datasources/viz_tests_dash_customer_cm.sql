{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}


select * 
from {{ ref('tests_dash_stg02_with_variant_arr') }}
