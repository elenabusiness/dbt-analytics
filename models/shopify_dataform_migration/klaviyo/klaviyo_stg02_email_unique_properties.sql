{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "klaviyo"
}


with email_table as (
select 
* except (email)
,lower(trim(first_value (email ignore nulls) over (partition by klaviyo_user_id order by upd_timestamp desc))) email
from {{ ref('klaviyo_stg01_customer_properties_unnested') }} 
)

,latest_by_klaviyo_id as(
select 
* 
from email_table
where email is not null
qualify rank() over (partition by email,klaviyo_user_id order by upd_timestamp desc, rand()) = 1
)

,email_with_props_arrays as
(
select 
email
,${settings.klaviyo_stg02_with_props_array_transformations}
group by email
)

,final as (
${settings.klaviyo_stg02_final_2_transformations}
from
(select distinct 
email
,${settings.klaviyo_stg02_final_1_transformations}
from email_with_props_arrays
))

select * 
from latest_by_klaviyo_id