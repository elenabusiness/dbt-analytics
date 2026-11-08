{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select * 
,iff(is_sub_churn_after_one_payment,DATEDIFF(day, order_date, sub_cancellation_date),null) days_to_sub_churn
from {{ ref('stg130_orderline_order_transformations') }} 