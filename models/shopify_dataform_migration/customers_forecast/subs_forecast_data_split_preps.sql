{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
  type: "table"}

select 1 as ttt

-- config {
--   type: "table",
--   schema: "customers_forecast"}


-- with base_preps as (
-- select 
-- order_date
-- ,order_id
-- ,split(customer_id,'_')[safe_offset(0)] customer_id
-- ,if(is_sub, sub_id,concat(split(customer_id,'_')[safe_offset(0)],'-','onetimesubs')) sub_id
-- ,is_sub
-- ,test_no
-- ,test_variant
-- ,orderline_discount discount_amount
-- ,orderline_price price
-- ,coalesce(sub_frequency_days,nosub_frequency_days) sub_frequency_days
-- ,ifnull(abs(orderline_paid_by_customer-orderline_total_refund)<=1,false) is_fully_refunded
-- ,sub_cancellation_date
-- from  {{ ref('base_orderlines') }} 
-- where customer_id is not null
-- and (sub_frequency_days is not null or nosub_frequency_days is not null)
--  )

-- ,base as (
-- select *, first_value(order_date) over (partition by customer_id, sub_id order by order_date) sub_start_date
-- , first_value(order_date) over (partition by customer_id order by order_date) customer_aquisition_date
-- ,date_add(order_date, interval sub_frequency_days day) order_date_next_expected
-- ,first_value(ifnull(safe_divide(discount_amount, price),0)) over (partition by customer_id, sub_id order by order_date) discount_percent_first_order
-- ,max(ifnull(safe_divide(discount_amount, price),0)) over (partition by customer_id, sub_id order by order_date) discount_percent_max
-- ,ifnull(safe_divide(
--   sum(ifnull(discount_amount,0)) over (partition by customer_id, sub_id order by order_date)
--   ,sum(ifnull(price,0)) over (partition by customer_id, sub_id order by order_date)
-- ),0) discount_percent_total
-- ,ifnull(concat(test_no,'--',test_variant),'N/A') vwo
-- from base_preps
--  where customer_id != '3405471776903'
--    )

-- ,base_dates as (
-- select * 
-- , not(is_early_cancellation or is_fully_refunded) is_success
-- ,max(is_early_cancellation) over (partition by customer_id) customer_had_early_cancellation 
-- from (select *
--   ,ifnull(cancellation_offset_days < sub_frequency_days/3,false) is_early_cancellation
--   ,sub_cancellation_date is not null is_cancelled
-- from (select *
-- ,if(is_first_sub_order, date_diff(sub_cancellation_date,order_date, day), null) cancellation_offset_days
-- from (select * except(sub_cancellation_date)
-- ,coalesce(sub_cancellation_date,if(current_date > order_date_next and is_latest_sub_order, date_add(order_date, interval 1 day),null)) sub_cancellation_date
-- ,if(is_latest_sub_order,null, date_diff(order_date_next,order_date_next_expected, day)) payment_offset_days
-- from (select * 
-- ,if(is_latest_sub_order
--     ,date_add(order_date, interval cast(floor(sub_frequency_days*1.3) as int64) day )
--     ,first_value(if(order_date_changed, order_date, null) ignore nulls) over (partition by customer_id, sub_id order by order_date asc, order_date_changed desc, order_id asc rows between 1 following and unbounded following) 
-- ) order_date_next
-- from( select *
-- ,order_rank_reversed = 1 is_latest_sub_order
-- ,order_rank = 1 is_first_sub_order
-- from (select *
-- ,ifnull(order_date != lead(order_date) over (partition by customer_id, sub_id order by order_date asc, order_id asc), true) order_date_changed
-- ,rank() over (partition by customer_id, sub_id order by order_date asc) order_rank
-- ,rank() over (partition by customer_id, sub_id order by order_date desc) order_rank_reversed
-- from base
-- ) ) ) ) ) ) 
-- )

-- ,base_successes as (
-- select *
-- ,max(not(is_sub)) over (partition by customer_id, sub_start_date) is_onetime_bought_together
-- ,customer_aquisition_date=sub_start_date is_new_customer
-- ,ifnull(floor(percentile_cont(payment_offset_days, 0.5 ignore nulls) over(partition by customer_id, sub_id)),0) payment_offset_days_median_days

-- from (select *
-- ,if(not is_success
--     ,first_value(if(is_success, null, order_date) ignore nulls) over (partition by customer_id order by order_date) 
--     ,order_date
-- ) order_date_last_success
-- from base_dates 
-- )
-- )

-- ,base_array as (
--   select * except(sub_ids_other)
--   ,array(select distinct sub_ids_other.sub_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.sub_id_ != sub_id
--   and order_date = sub_ids_other.order_date_
--   ) sub_ids_bought_together
-- ,array(
--   select distinct sub_ids_other.sub_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.sub_id_ != sub_id
--   and order_date between sub_ids_other.order_date_ and sub_ids_other.order_date_next_expected_
--   and sub_ids_other.sub_cancellation_date_ >= order_date
-- ) sub_ids_other_active_arr
-- ,array(
--   select distinct sub_ids_other.sub_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.sub_id_ != sub_id
--   and sub_ids_other.sub_cancellation_date_ <= order_date
-- ) sub_ids_cancelled_before_arr

-- ,array(
--   select distinct sub_ids_other.sub_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.sub_id_ != sub_id
--   and sub_ids_other.order_date_ <= order_date
-- ) sub_ids_bought_before_arr

-- ,array(
--   select distinct sub_ids_other.order_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.order_date_ <= order_date
-- ) orders_before_from_customer_arr

-- ,array(
--   select distinct sub_ids_other.order_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where ifnull(sub_ids_other.order_id_ != order_id,false) 
--   and order_date > sub_ids_other.order_date_
--   and not(is_success)
-- ) orders_refunded_before_arr


-- ,array(
--   select distinct order_id_ 
--   from (select * 
--   from unnest(sub_ids_other) sub_ids_other 
--   where ifnull(sub_ids_other.order_id_ != order_id,false) 
--   and order_date > sub_ids_other.order_date_
--   qualify ifnull(sub_ids_other.order_date_ > max(if(is_success, sub_ids_other.order_date_, null)) over (), true)
--   )
-- ) orders_refunded_sequentially_latest_arr


-- ,array(
--   select distinct order_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.sub_id_ = sub_id 
--   and sub_ids_other.order_id_ != order_id
--   and sub_ids_other.order_date_ >= order_date
--   and sub_ids_other.is_success_
-- ) orders_successfull_followup_arr


-- ,array(
--   select distinct order_id_ 
--   from unnest(sub_ids_other) sub_ids_other 
--   where sub_ids_other.sub_id_ = sub_id 
--   and sub_ids_other.order_id_ != order_id
--   and sub_ids_other.order_date_ >= order_date
-- ) orders_followup_arr

-- from (select * 
-- ,array_agg(struct(order_date as order_date_, order_date_next_expected as order_date_next_expected_, sub_cancellation_date as sub_cancellation_date_, sub_id as sub_id_, is_success as is_success_, order_id as order_id_)) over (partition by customer_id) sub_ids_other
-- from base_successes
-- )
-- )

-- ,base_tests as (
-- select *
-- ,ifnull(safe_divide(
--             count(distinct if(is_early_cancellation,sub_id,null)) over (partition by vwo, if(vwo is null, date_trunc(sub_start_date, week), null) )
--             ,count(distinct sub_id) over (partition by vwo, if(vwo is null, date_trunc(sub_start_date, week), null))
-- ),0) early_cancellation_avg_rate

-- from base_array
-- )

-- select *
-- ,case when orders_successfull_followup>=1 then true when is_cancelled then false else null end is_following_1_order_success
-- ,case when orders_successfull_followup>=2 then true when is_cancelled then false else null end is_following_2_order_success
-- ,case when orders_successfull_followup>=3 then true when is_cancelled then false else null end is_following_3_order_success
-- ,case when orders_successfull_followup>=4 then true when is_cancelled then false else null end is_following_4_order_success
-- ,case when orders_successfull_followup>=5 then true when is_cancelled then false else null end is_following_5_order_success
-- ,case when orders_successfull_followup>=6 then true when is_cancelled then false else null end is_following_6_order_success

-- from (select *
-- ,array_length(sub_ids_other_active_arr) sub_ids_other_active
-- ,array_length(sub_ids_cancelled_before_arr) sub_ids_cancelled_before
-- ,ifnull(safe_divide(array_length(sub_ids_cancelled_before_arr),array_length(sub_ids_bought_before_arr)),0) sub_ids_cancelled_before_rate
-- ,ifnull(safe_divide(array_length(orders_refunded_before_arr) , array_length(orders_before_from_customer_arr)),0) orders_refunded_before_rate
-- ,array_length(orders_before_from_customer_arr) orders_before_from_customer
-- ,array_length(orders_refunded_sequentially_latest_arr) orders_refunded_sequentially_latest
-- ,least(array_length(orders_successfull_followup_arr),6) orders_successfull_followup

-- ,case 
--   when rand() <= 0.8 then 'train'
--   else 'validate'
-- end split
-- from base_tests
-- where true
-- -- and (
-- --   sub_cancellation_date is not null
-- -- or
-- --   array_length(orders_followup_arr) >=6
-- -- )
-- )
