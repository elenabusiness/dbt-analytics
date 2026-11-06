{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with acquisition_dates as (
select distinct
customer_id
,customer_id_with_acquisition_rank
,acquisition_date_rank
,date acquisition_date
,is_customer_with_rank_retained
,is_customer_retained
from {{ ref('stg080_customer_status_by_date') }} 
where is_acquisition
)

select 
* except (acquisition_date_rank)
,acquisition_date date_from
,ifnull(date_add(lead(acquisition_date) over (partition by customer_id order by acquisition_date_rank asc),interval -1 day),current_date) date_to
from acquisition_dates