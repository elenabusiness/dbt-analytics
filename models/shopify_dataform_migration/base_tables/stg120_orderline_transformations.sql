{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select * 
,case 
when sub_frequency = 'onetime' then 'onetime'
when sub_frequency_days between 1 and 30 then '1-30 days'
when sub_frequency_days between 31 and 60 then '31-60 days'
when sub_frequency_days between 61 and 90 then '61-90 days'
when sub_frequency_days between 91 and 120 then '91-120 days'
when sub_frequency_days >= 121 then '120+ days'
end sub_frequency_group
from
(select *  
,case 
when sub_interval_unit='day' then 1
when sub_interval_unit='week' then 7
when sub_interval_unit='month' then 30
end * sub_interval_frequency::INT sub_frequency_days
,case 
when nosub_interval_unit='day' then 1
when nosub_interval_unit='week' then 7
when nosub_interval_unit='month' then 30
end * nosub_interval_frequency::INT nosub_frequency_days
from {{ ref('stg110_orderline_with_marketing_spend') }} 
)