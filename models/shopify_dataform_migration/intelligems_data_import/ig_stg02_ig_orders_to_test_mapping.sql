{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with all_orders as (
select
order_id
,object_construct('test_name', test_name, 'test_variant', test_variant) as ig_tests
from
(select distinct
order_id
,concat('IG - ', test_name) as test_name
,variant_name as test_variant
from {{ source('intelligems_source', 'intelligems_data_import_raw') }}
qualify rank() over (partition by order_id order by loaded_at_ts desc) = 1
and not (is_excluded)
))

,final as (
select
order_id
,array_agg(ig_tests) as ig_tests_arr
from all_orders
group by order_id
)

select *
from final
