{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"}

with offer_tubs_table as(
select * 
,case
when (variant_title like '%rehabilitation%' or variant_title like '%preventative%') and fpv7discount = '50' then '1 Tub'
when (variant_title like '%rehabilitation%' or variant_title like '%preventative%') and fpv7discount = '52' then '2 Tubs'
when (variant_title like '%rehabilitation%' or variant_title like '%preventative%') and fpv7discount = '58' then '3 Tubs'
when (variant_title like '%onetime%') and fpv7discount = '0' then '1 Tub'
when (variant_title like '%onetime%') and fpv7discount = '5' then '2 Tubs'
when (variant_title like '%onetime%') and fpv7discount = '10' then '3 Tubs'
when (variant_title like '%onetime%') and fpv7discount = '15' then '4 Tubs'
when (variant_title like '%onetime%') and fpv7discount = '20' then '5 Tubs'
when (variant_title like '%onetime%') and fpv7discount = '25' then '6 Tubs'
end offer_tubs
from {{ ref('customer_first_order_properties_with_tests_arr') }}
)

select
*
from offer_tubs_table
