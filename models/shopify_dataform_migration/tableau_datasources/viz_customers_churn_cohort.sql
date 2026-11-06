{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}


-- with variant_as_arr as (
-- select * except(test_variant_arr)
-- ,array(select distinct test_variant from unnest(test_variant_arr) test_variant where test_variant is not null and test_variant != '1') test_variant_arr
-- from (SELECT 
-- * 
-- ,if(test_variant = '1'
--   ,if(
--     count(distinct test_variant) over (partition by test_no) = 0
--     ,null
--     ,array_agg(test_variant) over (partition by test_no)
--   )
-- ,if(test_variant is null, null, [test_variant])
-- ) test_variant_arr
-- from {{ ref('customer_churn_cohort') }}
-- where customer_first_order_date >='2023-01-01' and is_last_day_of_month
-- ))

-- select 
-- * except (test_variant_arr,test_variant,test_no)
-- ,test_no vwo_test_no
-- ,if(test_variant = '1', 'Control',test_variant) vwo_variant
-- from variant_as_arr
-- left join unnest(test_variant_arr) vwo_variant_filter

select * except (tests_arr)
from {{ ref('customer_churn_cohort') }}
where customer_first_order_date >='2023-01-01' and is_last_day_of_month
