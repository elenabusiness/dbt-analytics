{{ config(
  materialized='table',
  schema = 'staging',
  enabled = false,
  ) }}

select 1 as placeholder
