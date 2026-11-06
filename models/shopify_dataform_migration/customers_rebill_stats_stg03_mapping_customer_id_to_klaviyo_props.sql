{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "sales_staging"
}

with joined_by_cid as (
select 
ids.*
,klaviyo_props_shopify_cid.accepts_marketing accepts_marketing_shopify_cid
,klaviyo_props_shopify_cid.amped_discount_code amped_discount_code_shopify_cid
,klaviyo_props_shopify_cid.email_exclusion_test email_exclusion_test_shopify_cid
,klaviyo_props_shopify_cid.free_gift free_gift_shopify_cid

,klaviyo_props_email.accepts_marketing accepts_marketing_email
,klaviyo_props_email.amped_discount_code amped_discount_code_email
,klaviyo_props_email.email_exclusion_test email_exclusion_test_email
,klaviyo_props_email.free_gift free_gift_email

,klaviyo_props_phone.accepts_marketing accepts_marketing_phone
,klaviyo_props_phone.amped_discount_code amped_discount_code_phone
,klaviyo_props_phone.email_exclusion_test email_exclusion_test_phone
,klaviyo_props_phone.free_gift free_gift_phone

from {{ ref('customers_rebill_stats_stg02_shopify_unique_customer_ids_emails_phones') }} ids
left join {{ ref('klaviyo_stg02_shopify_cid_unique_properties') }} klaviyo_props_shopify_cid
on ids.customer_id_original = klaviyo_props_shopify_cid.shopify_cid

left join {{ ref('klaviyo_stg02_email_unique_properties') }} klaviyo_props_email
on klaviyo_props_email.email = ids.email

left join {{ ref('klaviyo_stg02_phone_unique_properties') }} klaviyo_props_phone
on klaviyo_props_phone.phone = ids.phone
)

,all_props as (
select distinct customer_id_original, accepts_marketing,amped_discount_code,email_exclusion_test,free_gift
from
(select * except(
  accepts_marketing_shopify_cid,amped_discount_code_shopify_cid,email_exclusion_test_shopify_cid,free_gift_shopify_cid,
  accepts_marketing_email,amped_discount_code_email,email_exclusion_test_email,free_gift_email,
  accepts_marketing_phone,amped_discount_code_phone,email_exclusion_test_phone,free_gift_phone)
,coalesce(accepts_marketing_shopify_cid,accepts_marketing_email,accepts_marketing_phone) accepts_marketing
,coalesce(amped_discount_code_shopify_cid,amped_discount_code_email,amped_discount_code_phone) amped_discount_code
,coalesce(email_exclusion_test_shopify_cid,email_exclusion_test_email,email_exclusion_test_phone) email_exclusion_test
,coalesce(free_gift_shopify_cid,free_gift_email,free_gift_phone) free_gift
from joined_by_cid
))

,klaviyo_props_arrays as
(
select 
customer_id_original
,array_agg(distinct amped_discount_code ignore nulls) amped_discount_code_arr
,array_agg(distinct email_exclusion_test ignore nulls) email_exclusion_test_arr
,array_agg(distinct free_gift ignore nulls) free_gift_arr
,max(accepts_marketing) accepts_marketing
from all_props
group by customer_id_original
)

,final as (
select * except (amped_discount_code,email_exclusion_test,free_gift)
,nullif(amped_discount_code,'') amped_discount_code
,nullif(email_exclusion_test,'') email_exclusion_test
,nullif(free_gift,'') free_gift
from
(select distinct 
customer_id_original
,array_to_string(array(select distinct amped_discount_code from unnest(amped_discount_code_arr) amped_discount_code where amped_discount_code is not null order by amped_discount_code),' | ' ) amped_discount_code
,array_to_string(array(select distinct email_exclusion_test from unnest(email_exclusion_test_arr) email_exclusion_test where email_exclusion_test is not null order by email_exclusion_test),' | ' ) email_exclusion_test
,array_to_string(array(select distinct free_gift from unnest(free_gift_arr) free_gift where free_gift is not null order by free_gift),' | ' ) free_gift
,accepts_marketing
from klaviyo_props_arrays
))

select * from final