{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

select * exclude (sub_type_klaviyo, dog_weight_klaviyo_product_prop, dog_weight_variant)
,coalesce(dog_weight_variant, dog_weight_klaviyo_product_prop) as dog_weight_from_product
,coalesce(sub_type_variant, sub_type_klaviyo) as sub_type
from {{ ref('stg040_orderline_tags_from_variant_title') }}
