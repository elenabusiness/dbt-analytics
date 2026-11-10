{{ config(
  materialized='table',
  
  ) }}
select 
*
from {{ ref('cro_dashboard_stg01_required_metrics') }}
