{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select *
,null ig_test_group
, null test_group_id_note_attributes
, null test_name_note_attributes
, null vwo_test_note_attributes
,null klaviyo_vwo_test_no
,null klaviyo_vwo_variant
, null test_group_name_note_attributes
,null vwo_variant_note_attributes
from {{ ref('stg010_orderline_clean') }}