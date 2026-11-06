{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with all_orders as (
select distinct
'IG - 0-35: Restrict tub options to lower rebill period' as test_name
,variation_name as test_variant
,order_id
,is_outlier
from {{ ref('ig_out_of_stock_0_35_orders_table') }}

union all

select distinct
'IG - 36-65: Restrict tub options to lower rebill period' as test_name
,variation_name as test_variant
,order_id
,is_outlier
from {{ ref('ig_out_of_stock_35_65_orders_table') }}

union all

select distinct
'IG - 65-100: Restrict tub options to lower rebill period' as test_name
,variation_name as test_variant
,order_id
,is_outlier
from {{ ref('ig_out_of_stock_65_100_orders_table') }}

union all

select distinct
'IG - 100-120: Restrict tub options to lower rebill period' as test_name
,variation_name as test_variant
,order_id
,is_outlier
from {{ ref('ig_out_of_stock_100_120_orders_table') }}

union all

select distinct
'IG - 120+: Restrict tub options to lower rebill period' as test_name
,variation_name as test_variant
,order_id
,is_outlier
from {{ ref('ig_out_of_stock_120_plus_orders_table') }}
)

select *
from all_orders
where not (is_outlier)
qualify rank() over (partition by order_id order by test_name asc, test_variant asc) = 1
