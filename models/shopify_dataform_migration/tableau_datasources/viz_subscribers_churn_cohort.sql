{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
SELECT * 
FROM {{ ref('subscribers_churn_cohort') }}
where customer_first_order_date >='2023-01-01' and is_last_day_of_month