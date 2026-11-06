{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "visualisation_preps"
}


with variant_as_arr as (
select * except(vwo_variant_arr)
,array(select distinct vwo_variant from unnest(vwo_variant_arr) vwo_variant where vwo_variant is not null and vwo_variant != '1') vwo_variant_arr
from (SELECT 
*
,if(vwo_variant = 'Control'
  ,if(
    count(distinct vwo_variant) over (partition by vwo_test_no) = 0
    ,null
    ,array_agg(vwo_variant) over (partition by vwo_test_no)
  )
,if(vwo_variant is null, null, [vwo_variant])
) vwo_variant_arr
from {{ ref('tests_dashboard_stg01_required_metrics') }}
where first_order_date >='2023-01-01' 
))

,variant_as_arr_unnested as(
select 
* except (vwo_variant_arr,vwo_variant)
,if(vwo_variant = 'Control', 'Control',vwo_variant) vwo_variant
from variant_as_arr
left join unnest(vwo_variant_arr) vwo_variant_filter
)

select * 
,rank() over (partition by vwo_test_no, vwo_variant,customer_id, order_id,sku order by vwo_variant_filter asc) = 1 is_variant_first_instance
from variant_as_arr_unnested

