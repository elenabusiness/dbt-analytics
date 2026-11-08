{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

with all_data_with_source_url as(
select * 
EXCLUDE (source_url)
,REGEXP_SUBSTR(source_url, '^[^?#]*') source_url
,dense_rank() over (partition by customer_id order by order_timestamp desc) = 1 is_last_order
from {{ ref('stg120_orderline_transformations') }} 
)

, order_rank as (
select * EXCLUDE (order_rank)
,max(order_rank) over (partition by order_id) order_rank
from
(select * EXCLUDE (order_rank)
,iff(order_has_refund_last_order and sub_status = 'cancelled' and is_last_order,null,dense_rank() over (partition by customer_id order by order_timestamp asc)) order_rank
from
(select *
,dense_rank() over (partition by customer_id order by order_timestamp asc) order_rank
,first_value(order_has_refund) over (partition by customer_id order by is_last_order desc, order_date desc rows between unbounded preceding and unbounded following) order_has_refund_last_order
from all_data_with_source_url
)))

, all_data_with_rebills_info as 
(select * EXCLUDE (is_there_next_order,is_expected_next_order_date_in_past,is_order_success)
,is_there_next_order or is_expected_next_order_date_in_past is_next_order_completed
,is_order_success
,not(is_there_next_order) and is_expected_next_order_date_in_past is_customer_churned_after_this_order
from
(select *
,max(order_rank) over (partition by customer_id) > order_rank is_there_next_order
,ifnull(max_expected_next_order_date_order_level<current_date,true) is_expected_next_order_date_in_past
,not(order_has_refund) is_order_success
,true is_order
from
(select * 
,iff(order_has_sub,rank() over(partition by customer_id, order_has_sub order by order_timestamp asc)=1,null) is_first_order_with_sub
,dense_rank() over (partition by customer_id order by order_timestamp asc) = 2 is_second_order
,dense_rank() over (partition by customer_id order by order_timestamp asc) = 3 is_third_order
,max(expected_next_order_date_orderline_level) over (partition by order_id) max_expected_next_order_date_order_level
,min(expected_next_order_date_orderline_level) over (partition by order_id) min_expected_next_order_date_order_level
from order_rank
))
)

select *
from all_data_with_rebills_info