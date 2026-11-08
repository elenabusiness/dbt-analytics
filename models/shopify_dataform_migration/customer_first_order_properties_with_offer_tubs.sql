{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with offer_tubs_table as(
select * 
,    DECODE(UNIFORM(1, 6, RANDOM()),
        1, '1 Tub',
        2, '2 Tubs',
        3, '3 Tubs',
        4, '4 Tubs',
        5, '5 Tubs',
        6, '6 Tubs'
    ) AS  offer_tubs
from {{ ref('customer_first_order_properties_with_tests_arr') }}
)

select
*
from offer_tubs_table
