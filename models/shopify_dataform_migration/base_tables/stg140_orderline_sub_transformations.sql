{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select * 
,if(is_sub_churn_after_one_payment,date_diff(sub_cancellation_date,order_date,day),null) days_to_sub_churn
from {{ ref('stg130_orderline_order_transformations') }} 