{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}

select 
*
from {{ ref('cro_dashboard_stg01_required_metrics') }}
