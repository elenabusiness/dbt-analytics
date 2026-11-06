{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

select orderlines.* exclude (test_no, test_variant)
,coalesce(manual_upload.test_name, orderlines.test_no) as test_no
,coalesce(manual_upload.test_variant, orderlines.test_variant) as test_variant
from {{ ref('stg0203_orderline_test_no_and_variant') }} as orderlines
left join {{ ref('ig_out_of_stock_orders') }} as manual_upload
  on orderlines.order_id = manual_upload.order_id
