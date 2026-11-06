{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

select
cast(order_id as string) as order_id
,sum(cast(amount as float)) as dispute_amount
,min(finalized_on) as dispute_date
from {{ source('shopify_source', 'disputes') }}
where lower(status) = 'lost'
group by order_id
