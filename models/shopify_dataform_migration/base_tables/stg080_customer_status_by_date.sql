{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with orders as (
select
order_id
,order_date
,order_timestamp
,customer_id
,customer_first_order_date
,is_sub
,sub_id
,sub_status
,sub_cancellation_date
,expected_next_order_date_orderline_level
from {{ ref('stg070_orderline_expected_next_order_date') }}
)

,customers_all_dates as (
  select distinct
    c.customer_id
    ,c.customer_first_order_date
    ,dateadd(day, f.value::int, c.start_date) as date
  from (
    select
      customer_id
      ,customer_first_order_date
      ,min(order_date) as start_date
      ,dateadd(day, 1, last_day(max(ifnull(iff(sub_status = 'active', current_date, coalesce(sub_cancellation_date, expected_next_order_date_orderline_level)), order_date)))) as end_date
    from orders
    group by customer_id, customer_first_order_date
  ) c,
  lateral flatten(
    input => array_generate_range(0, datediff(day, c.start_date, c.end_date) + 1),
    outer => true
  ) f
)

,subs_all_dates as (
  select distinct
    s.customer_id
    ,s.sub_id
    ,dateadd(day, f.value::int, s.start_date) as date_sub_is_active
    ,true as is_active_due_to_sub
  from (
    select
      customer_id, sub_id
      ,min(order_date) as start_date
      ,ifnull(max(sub_cancellation_date), current_date) as end_date
    from orders
    where is_sub
    group by customer_id, sub_id
  ) s,
  lateral flatten(
    input => array_generate_range(0, datediff(day, s.start_date, s.end_date) + 1),
    outer => true
  ) f
)

,orders_all_dates as (
  select distinct
    o.customer_id
    ,dateadd(day, f.value::int, o.start_date) as date_order_is_active
    ,true as is_active_due_to_onetime
  from (
    select
      customer_id, order_id
      ,min(order_date) as start_date
      ,ifnull(max(expected_next_order_date_orderline_level), min(order_date)) as end_date
    from orders
    where not is_sub
    group by customer_id, order_id
  ) o,
  lateral flatten(
    input => array_generate_range(0, datediff(day, o.start_date, o.end_date) + 1),
    outer => true
  ) f
)

,customer_all_orders_all_dates as
(select *
,ifnull(date = coalesce(date_sub_is_active,date_order_is_active),false) is_customer_active
,ifnull(date = date_sub_is_active,false) is_subscriber_active
from (select
customers_all_dates.*
,subs_all_dates.* exclude(customer_id )
,orders_all_dates.* exclude(customer_id)
from customers_all_dates
left join subs_all_dates
on customers_all_dates.customer_id=subs_all_dates.customer_id and customers_all_dates.date=subs_all_dates.date_sub_is_active
left join orders_all_dates
on customers_all_dates.customer_id=orders_all_dates.customer_id and customers_all_dates.date=orders_all_dates.date_order_is_active
))

,customer_status_by_date as(
select
customer_all_orders_all_dates.customer_id
,customer_all_orders_all_dates.customer_first_order_date
,customer_all_orders_all_dates.date
,customer_all_orders_all_dates.is_customer_active
,customer_all_orders_all_dates.is_active_due_to_sub
,customer_all_orders_all_dates.is_active_due_to_onetime
,is_customer_active and not ifnull(lag(is_customer_active) over (partition by customer_all_orders_all_dates.customer_id order by date asc),true) is_reactivation
,date = last_day(date, month) or date = current_date() is_last_day_of_month
,date = last_day(date, week) or date = current_date() is_last_day_of_week
,date = customer_first_order_date or mod(datediff(day, customer_first_order_date, date) + 1, 15) = 0 or date = current_date() or date = first_value(date) over(partition by customer_id order by date desc) is_last_day_of_15day_interval
from customer_all_orders_all_dates
where date <=current_date()
)

,customer_status_by_date_with_churn_date_intervals as(
select *
,iff(is_customer_active,null,first_value(iff(is_customer_active or date<last_active_date, null, date) ignore nulls) over (partition by customer_id,last_active_date order by date asc rows between unbounded preceding and current row)) churn_date
from (select * 
,last_value(iff(is_customer_active,date,null) ignore nulls) over (partition by customer_id order by date asc rows between unbounded preceding and current row) last_active_date
from customer_status_by_date
))


,with_new_acquisition_after_60_days_churn as (
select *
,iff(is_reactivation,lag(days_churned) over(partition by customer_id order by date asc)>60,false) or date = customer_first_order_date is_acquisition
from
(select *
,iff(not(is_customer_active),dense_rank() over(partition by customer_id, churn_date order by date),null) days_churned
from customer_status_by_date_with_churn_date_intervals
))

select * 
,max(date = current_date and is_customer_active) over (partition by customer_id_with_acquisition_rank) is_customer_with_rank_retained
,max(date = current_date and is_customer_active) over (partition by customer_id) is_customer_retained
from 
(select *
,concat(concat(customer_id,'_'),cast(acquisition_date_rank as string)) customer_id_with_acquisition_rank
from
(select *
,dense_rank () over (partition by customer_id order by acquisition_date asc) acquisition_date_rank
from
(select * 
,first_value(iff(is_acquisition,date,null)ignore nulls) over (partition by customer_id order by date desc rows between current row and unbounded following) acquisition_date
from with_new_acquisition_after_60_days_churn))
)