{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
select 
*
from {{ ref('cro_dashboard_stg01_required_metrics') }}
