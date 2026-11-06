{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "klaviyo"
}


with shopify_cid_table as (
select 
* except (shopify_cid)
,lower(trim(first_value (shopify_cid ignore nulls) over (partition by klaviyo_user_id order by upd_timestamp desc))) shopify_cid
from {{ ref('klaviyo_stg01_customer_properties_unnested') }} 
)

,latest_by_klaviyo_id as(
select 
* 
from shopify_cid_table
where shopify_cid is not null
qualify rank() over (partition by shopify_cid,klaviyo_user_id order by upd_timestamp desc, rand()) = 1
)

,shopify_cid_with_props_arrays as
(
select 
shopify_cid
,${settings.klaviyo_stg02_with_props_array_transformations}
group by shopify_cid
)

,final as (
${settings.klaviyo_stg02_final_2_transformations}
from
(select distinct 
shopify_cid
,${settings.klaviyo_stg02_final_1_transformations}
from shopify_cid_with_props_arrays
))

select * 
from latest_by_klaviyo_id