{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
with base as (
  select 
 concat(customer_id, sub_id) sub_id
,concat(FORMAT_TIMESTAMP('%Y-%m', sub_start_date), '-',vwo,'-', if(is_sub,'sub','onetime')) weektestsubtype
-- ,sub_frequency_days
,case 
when sub_frequency_days between 0 and 31 then 'Under_31_days'
when sub_frequency_days between 32 and 63 then 'Under_63_days'
when sub_frequency_days between 64 and 94 then 'Under_94_days'
when sub_frequency_days between 95 and 126 then 'Under_126_days'
when sub_frequency_days > 126 then 'Over_126_days'
end sub_frequency_days
,order_rank
,ifnull(sub_cancellation_date < order_date_next_expected,false) is_cancellation
 FROM `wuffes-data.customers_forecast.subs_forecast_data_split_preps` 
where order_rank <=4
-- and vwo = 'N/A'
and is_sub
and sub_frequency_days in (14,15,20,21,28,30,31,35,37,40, 42,45,47,56,60,63,70,74,84,90,94,120,126,150,180,240,360)

)

select * from (
select 
sub_frequency_days, order_rank,weektestsubtype, count(distinct sub_id) subs
, count(distinct if(is_cancellation,sub_id,null)) cancels
from base
group by sub_frequency_days, order_rank, weektestsubtype
)
pivot (
  sum(cancels/subs) as rate, sum(subs) as subs for sub_frequency_days in ('Under 31 days','Under 63 days','Under 94 days','Under 126 days','Over 126 days')
  -- sub_frequency_days in (14,15,20,21,28,30,31,35,37,40, 42,45,47,56,60,63,70,74,84,90,94,120,126,150,180,240,360)
)
order by weektestsubtype desc, order_rank


-- select 
-- sub_id, weektestsubtype
-- case when weektestsubtype
-- order by sub_id, order_rank