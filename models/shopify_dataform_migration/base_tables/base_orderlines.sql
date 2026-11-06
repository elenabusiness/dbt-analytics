{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select *
FROM {{ ref('stg150_orderline_customer_transformations') }} order_lines