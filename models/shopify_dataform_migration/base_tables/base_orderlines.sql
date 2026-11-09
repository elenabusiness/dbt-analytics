{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}

select *
,'dummy' dummy_chane_column
,'dummy' dummy_fix_column1
,'test git add' git_add_column
FROM {{ ref('stg150_orderline_customer_transformations') }} order_lines