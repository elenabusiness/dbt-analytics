{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "klaviyo"
}


with phone_table as (
select 
* except (phone)
,lower(trim(first_value (phone ignore nulls) over (partition by klaviyo_user_id order by upd_timestamp desc))) phone
from {{ ref('klaviyo_stg01_customer_properties_unnested') }} 
)

,latest_by_klaviyo_id as(
select 
* 
from phone_table
where phone is not null
qualify rank() over (partition by phone,klaviyo_user_id order by upd_timestamp desc, rand()) = 1
)

,phone_with_props_arrays as
(
select 
phone
,${settings.klaviyo_stg02_with_props_array_transformations}
group by phone
)

,final as (
${settings.klaviyo_stg02_final_2_transformations}
from
(select distinct 
phone
,${settings.klaviyo_stg02_final_1_transformations}
from phone_with_props_arrays
))

select * 
from latest_by_klaviyo_id