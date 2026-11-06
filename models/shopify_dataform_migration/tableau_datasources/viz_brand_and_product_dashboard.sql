{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}

select * 
from {{ ref('brand_and_product_dashboard') }}
