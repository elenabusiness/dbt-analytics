{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with base as (
SELECT
*
,iff(vwo_variant = 'Control'
  ,iff(
    count(distinct vwo_variant) over (partition by vwo_test_no) = 0
    ,null
    ,array_agg(vwo_variant) over (partition by vwo_test_no)
  )
,iff(vwo_variant is null, null, ARRAY_CONSTRUCT(vwo_variant))
) vwo_variant_arr
from {{ ref('tests_dashboard_stg01_required_metrics') }}
where first_order_date >='2023-01-01'
)

, variant_as_arr as (
select * EXCLUDE (vwo_variant_arr)
,ARRAY_COMPACT(ARRAY_DISTINCT(ARRAY_REMOVE(vwo_variant_arr, '1'::variant))) as vwo_variant_arr
from base
)

,variant_as_arr_unnested as(
select
* EXCLUDE (vwo_variant_arr, vwo_variant)
,iff(vwo_variant = 'Control', 'Control', vwo_variant_filter.value::string) vwo_variant
from variant_as_arr
,lateral flatten(input=>vwo_variant_arr, outer=>true) vwo_variant_filter
)

select *
,rank() over (partition by vwo_test_no, vwo_variant, customer_id, order_id, sku order by vwo_variant asc) = 1 is_variant_first_instance
from variant_as_arr_unnested

