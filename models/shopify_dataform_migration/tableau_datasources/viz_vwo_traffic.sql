{{ config(
  materialized='table',
  schema = 'staging',
  enabled = false,
  ) }}
with variant_as_arr as (
select * EXCLUDE (vwo_variant_arr)
,array(select distinct vwo_variant from unnest(vwo_variant_arr) vwo_variant where vwo_variant is not null and vwo_variant != '1') vwo_variant_arr
from
(select * 
,iff(vwo_variant = '1'
  ,iff(
    count(distinct vwo_variant) over (partition by vwo_test_no) = 0
    ,null
    ,array_agg(vwo_variant) over (partition by vwo_test_no)
  )
,iff(vwo_variant is null, null, [vwo_variant])
) vwo_variant_arr
from {{ ref('vwo_test_traffic_clean') }} 
))

select 
* EXCLUDE (vwo_variant_arr,vwo_variant)
,iff(vwo_variant = '1', 'Control',vwo_variant) vwo_variant
from variant_as_arr
left join unnest(vwo_variant_arr) vwo_variant_filter