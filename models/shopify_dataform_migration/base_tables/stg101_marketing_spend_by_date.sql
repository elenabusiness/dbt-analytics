{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with fb_daily as(
select 
'facebook' source
,date(date_start) date
,sum(spend) cost
from
`stitch-data-296516.facebook.ads_insights`
group by source,date
)

,ga_daily as(
select 
'google' source
,date(date) date
,sum(cost_micros)/1000000 cost
from `stitch-data-296516.google.ad_performance_report` 
group by source, date
)

select 
date,sum(cost) cost
from
(select
source,date,cost
from fb_daily
union all
select
source,date,cost
from ga_daily)
group by date