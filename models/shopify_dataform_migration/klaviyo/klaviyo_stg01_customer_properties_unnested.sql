{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "klaviyo"}


with all_data as(
select 
-- *,
attributes
,updated upd_timestamp
,id klaviyo_user_id
,trim(initcap(json_extract_scalar(attributes,'$.first_name'))) first_name
,trim(initcap(json_extract_scalar(attributes,'$.last_name'))) last_name
,trim(lower(json_extract_scalar(attributes,'$.email'))) email
,nullif(regexp_replace(json_extract_scalar(attributes,'$.phone_number'), r'[^0-9]', ''),'') phone
,json_extract(attributes,'$.location') location_json
,json_extract(attributes,'$.properties') properties_json
from `stitch-data-296516.klaviyo.profiles`
)

, properties_extracted as (
select * 
except(attributes,properties_json, location_json)

,json_extract_scalar(properties_json,'$.Accepts Marketing') accepts_marketing
,json_extract_scalar(properties_json,'$.Amped - Discount Code') amped_discount_code
,json_extract_scalar(properties_json,'$.rc_external_customer_id') shopify_cid
,json_extract_scalar(properties_json,'$.Email Exclusion Test') email_exclusion_test
,json_extract_scalar(properties_json,'$.Free_Gift') free_gift


from all_data
)

, properties_clean as (
select * 
except(accepts_marketing)
,ifnull(case accepts_marketing
when 'false' then 'no'
when 'true' then 'yes'
else accepts_marketing 
end, 'no') accepts_marketing
from properties_extracted
)
select 
*
from properties_clean
