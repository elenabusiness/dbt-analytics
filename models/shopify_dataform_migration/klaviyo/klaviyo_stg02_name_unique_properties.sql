{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table",
  schema: "klaviyo"
}


with name_table as (
select 
* except (first_name, last_name)
,lower(trim(first_value (first_name ignore nulls) over (partition by klaviyo_user_id order by upd_timestamp desc))) first_name
,lower(trim(first_value (last_name ignore nulls) over (partition by klaviyo_user_id order by upd_timestamp desc))) last_name
from {{ ref('klaviyo_stg01_customer_properties_unnested') }} 
)

,latest_by_klaviyo_id as(
select 
* 
from name_table
where first_name is not null and last_name is not null
qualify rank() over (partition by first_name, last_name,klaviyo_user_id order by upd_timestamp desc, rand()) = 1
)

,name_with_props_arrays as
(
select 
first_name, last_name
,${settings.klaviyo_stg02_with_props_array_transformations}
group by first_name, last_name
)

,final as (
${settings.klaviyo_stg02_final_2_transformations}
from
(select distinct 
first_name, last_name
,${settings.klaviyo_stg02_final_1_transformations}
from name_with_props_arrays
))

select * 
from latest_by_klaviyo_id