{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
-- -- select customer_id, order_date, order_name, order_id, test_no vwo_test_no, test_variant vwo_variant, vwo_test_original, vwo_variant_original
-- from {{ ref('customer_ltv_cohort_order_line_level') }} 
-- group by customer_id, order_date, order_name, order_id, vwo_test_no, vwo_variant, vwo_test_original, vwo_variant_original

select 1 as ttt