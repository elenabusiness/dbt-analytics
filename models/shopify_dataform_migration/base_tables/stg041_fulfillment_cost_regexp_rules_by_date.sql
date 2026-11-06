{{ config(
  materialized='table',
  schema = 'staging',

  ) }}

with rules as (
select
cast(rule_order as int) as rule_order
,lower(shipping_type) as shipping_type_regexp
,try_to_date(trim(start_date), 'MM/DD/YYYY') as start_date
,try_to_date(trim(end_date), 'MM/DD/YYYY') as end_date
,cast(fulfillment_cost as float) as fulfillment_cost
from {{ ref('fulfillment_cost_federated') }}
where shipping_type is not null
and (start_date is null or try_to_date(trim(start_date), 'MM/DD/YYYY') is not null)
and (end_date is null or try_to_date(trim(end_date), 'MM/DD/YYYY') is not null)
)

,date_spine as (
select dateadd(day, seq4(), '2020-01-01')::date as date
from table(generator(rowcount => 3650))
)

,rules_by_date as (
select
r.fulfillment_cost
,r.shipping_type_regexp
,r.rule_order
,ds.date
from rules as r
cross join date_spine as ds
where ds.date between ifnull(r.start_date, '2020-01-01') and ifnull(r.end_date, current_date())
)

select distinct
first_value(fulfillment_cost) over (partition by shipping_type_regexp, date order by rule_order desc) as fulfillment_cost
,shipping_type_regexp
,rule_order
,date
from rules_by_date
