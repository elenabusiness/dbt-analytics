{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

select * exclude (latest)
from
(select *
,rank() over (partition by sku order by start_date desc, random()) = 1 as latest
from {{ ref('cogs_federated') }})
where latest
