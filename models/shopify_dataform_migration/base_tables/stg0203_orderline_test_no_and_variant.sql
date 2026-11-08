{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with intelligems_test_names_clean as (
select
orderlines.* exclude (ig_test_group, test_group_id_note_attributes)
,concat('IG - ', ifnull(ig_names_2.test_name, ig_test_group)) as ig_test_name
,ifnull(ig_names_2.variant_name, ig_test_group) as ig_variant_name
from {{ ref('stg020_orderline_klaviyo_tags') }} as orderlines
left join {{ ref('stg0201_orderline_intelligems_tags') }} as ig_names_2
  on orderlines.test_group_id_note_attributes = ig_names_2.variant_id
)
,vwo_test_names_clean as (
select * exclude (test_name_note_attributes, klaviyo_vwo_test_no, vwo_test_note_attributes)
,concat('IG - ', test_name_note_attributes) as test_name_note_attributes
,concat('VWO - ', klaviyo_vwo_test_no) as klaviyo_vwo_test_no
,concat('VWO - ', vwo_test_note_attributes) as vwo_test_note_attributes
from intelligems_test_names_clean
)

,tests as (
select
* exclude (klaviyo_vwo_test_no, test_name_note_attributes, ig_test_name, ig_variant_name, vwo_variant_note_attributes, test_group_name_note_attributes)
,iff(order_date >= '2024-01-19' and (vwo_test_note_attributes is not null or vwo_variant_note_attributes is not null), vwo_test_note_attributes, klaviyo_vwo_test_no) as test_no
,iff(order_date >= '2024-01-19' and (vwo_test_note_attributes is not null or vwo_variant_note_attributes is not null), vwo_variant_note_attributes, klaviyo_vwo_variant) as test_variant
from vwo_test_names_clean
)

,test_267_rules as (
select * exclude (test_no, test_variant)
,case
  when order_date between '2024-04-04' and '2024-04-15' and rlike(source_url, 'pages\\/full-price-jc-v7') then 'VWO - 267'
  when order_date between '2024-04-10' and '2024-04-15' and rlike(source_url, 'pages/jointchew-offer') then 'VWO - 267'
  when test_no != 'VWO - 267' then test_no
end as test_no
,case
  when order_date between '2024-04-04' and '2024-04-15' and rlike(source_url, 'pages\\/full-price-jc-v7') then '2'
  when order_date between '2024-04-10' and '2024-04-15' and rlike(source_url, 'pages/jointchew-offer') then '1'
  when test_no != 'VWO - 267' then test_variant
end as test_variant
from tests
)

select *
from test_267_rules
