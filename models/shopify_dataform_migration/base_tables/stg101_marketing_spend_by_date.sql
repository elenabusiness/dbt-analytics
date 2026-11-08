{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with fb_daily as (
  select
    'facebook' as source,
    date as date,
    sum(spend) as cost
  from {{ source('meta_ads_source', 'basic_ad') }}
  group by source, date
)

select
  date,
  sum(cost) as cost
from fb_daily
group by date