{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select *
,'dummy' dummy_chane_column
,'dummy' dummy_fix_column1
FROM {{ ref('stg150_orderline_customer_transformations') }} order_lines