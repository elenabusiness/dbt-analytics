{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with new_customer_ids as (
select 
orderlines.* 
,acquisition_dates.customer_id_with_acquisition_rank customer_id_with_acquisition_rank_temp
,acquisition_dates.is_customer_retained
,acquisition_dates.is_customer_with_rank_retained
from {{ ref('stg070_orderline_expected_next_order_date') }} orderlines
left join {{ ref('stg090_customer_acquisition_dates_and_new_ids') }} acquisition_dates
on orderlines.customer_id = acquisition_dates.customer_id and orderlines.order_date between acquisition_dates.date_from and acquisition_dates.date_to
)

select * 
,rank() over (partition by customer_id order by order_timestamp asc) = 1 is_first_order
,first_value(order_date) over(partition by customer_id order by order_timestamp asc) customer_first_order_date
from
(select * 
except (customer_id,is_customer_retained,is_customer_with_rank_retained,is_first_order,customer_first_order_date)
,customer_id_with_acquisition_rank_temp customer_id
,is_customer_with_rank_retained is_retained_customer
,is_first_order is_first_order_original
,customer_id customer_id_original
from new_customer_ids)