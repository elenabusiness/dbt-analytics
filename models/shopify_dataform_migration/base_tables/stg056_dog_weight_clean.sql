{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

select * exclude (latest)
from
(select
trim(lower(dog_weight_raw)) as dog_weight_raw
,trim(lower(dog_weight_category)) as dog_weight_category
,rank() over (partition by dog_weight_raw order by cast(rule_order as int) desc, random()) = 1 as latest
from {{ ref('dog_weight_federated') }})
where latest
