{{ config(
  materialized='table',
  schema = 'staging',
  enabled = false,
  ) }}

with vwo_variant_names_lookup as
(select * exclude (latest)
from
(select
trim(lower(vwo_test_name)) as vwo_test_name
,trim(lower(vwo_test_no)) as vwo_test_no
,trim(lower(vwo_variant)) as vwo_variant
,trim(lower(bi_name)) as bi_name
,rank() over (partition by vwo_test_no, vwo_variant order by trim(lower(vwo_variant)) desc) = 1 as latest
from {{ ref('vwo_variant_names_lookup') }})
where latest)

,traffic as
(select
coalesce(try_to_date(trim(date), 'DD/MM/YY'), try_to_date(trim(date), 'MM/DD/YY')) as date
,trim(lower(cast(campaign_id as string))) as campaign_id
,trim(lower(variation_name)) as variation_name
,visitors
,cast(trim(conversions) as int) as conversions
from
(select *
,rank() over (partition by campaign_id, variation_name, date order by timestamp_streamed desc) = 1 as latest
from {{ source('vwo_source', 'daywise_data') }}
where lower(goal) = 'checkouts')
where latest
)

,traffic_clean as (
select
traffic.campaign_id as vwo_test_no
,vwo_variant_names_lookup.vwo_variant
,traffic.date
,sum(traffic.visitors) as visitors
,sum(traffic.conversions) as conversions
from traffic
left join vwo_variant_names_lookup
on traffic.campaign_id = vwo_variant_names_lookup.vwo_test_no and traffic.variation_name = vwo_variant_names_lookup.bi_name
group by
traffic.campaign_id
,vwo_variant_names_lookup.vwo_variant
,traffic.date
)

select *
from traffic_clean
