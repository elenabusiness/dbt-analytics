{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

select *
,regexp_substr(lower(orderline_variant_title), '(\\d+-\\d+ lbs|\\d+\\+ lbs|over \\d+ lbs)', 1, 1, 'e') as dog_weight_variant
,regexp_substr(lower(orderline_variant_title), '(single|double) sub', 1, 1, 'e') as sub_type_variant
from {{ ref('stg030_orderline_with_sub_ids') }}
