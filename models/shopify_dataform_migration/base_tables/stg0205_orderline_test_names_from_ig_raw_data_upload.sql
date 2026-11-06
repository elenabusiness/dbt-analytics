{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with order_distinct_tests as (
select
order_id
,object_construct('test_no', test_no, 'test_variant', test_variant) as tests_from_tags
from
(select distinct
order_id, test_no, test_variant
from {{ ref('stg0204_orderline_manual_test_upload') }} as orderlines
)
)

,order_distinct_tests_arr as (
select
order_id
,array_agg(tests_from_tags) as tests_from_tags_arr
from order_distinct_tests
group by order_id
)

,orderlines_with_tests_arr as (
select orderlines.* exclude (test_no, test_variant)
,order_distinct_tests_arr.tests_from_tags_arr
from {{ ref('stg0204_orderline_manual_test_upload') }} as orderlines
left join order_distinct_tests_arr
  on orderlines.order_id = order_distinct_tests_arr.order_id
)

,join_with_ig_raw_data as (
select orderlines_with_tests_arr.* exclude (tests_from_tags_arr)
,coalesce(ig_raw.ig_tests_arr, orderlines_with_tests_arr.tests_from_tags_arr) as tests_arr
from orderlines_with_tests_arr
left join {{ ref('ig_stg02_ig_orders_to_test_mapping') }} as ig_raw
  on orderlines_with_tests_arr.order_id = ig_raw.order_id
)

select *
from join_with_ig_raw_data
