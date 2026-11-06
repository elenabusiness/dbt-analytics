{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with all_tests_names as (
select
cast(rule_order as int) as rule_order
,ifnull(trim(test_name), 'No Name') as test_name
,trim(variant_name) as variant_name
,trim(variant_id) as variant_id
from {{ ref('intelligems_mapping') }}
)

select
variant_id
,test_name
,variant_name
from all_tests_names
qualify rank() over (partition by variant_id order by rule_order desc) = 1
