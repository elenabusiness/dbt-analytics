{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "tableau_datasources"
}

select * except (source_type)
,if (source_type = '',null,source_type) source_type
from
(select * except (source_type_arr)
,array_to_string(array(select distinct source_type from unnest(source_type_arr) source_type where source_type is not null order by source_type),' | ' ) source_type
,case 
when day between 1 and 7 then '1-7'
when day between 8 and 14 then '8-14'
when day between 15 and 21 then '15-21'
when day between 21 and 28 then '21-28'
when day >28 then '29+'
end days_interval
from
(select 
customer_id
,order_date
,order_id
,orderline_cm order_cm
,orderline_cm_less_cac order_cm_less_cac
,array_agg(if(is_first_order,source_type,null)) over (partition by customer_id) source_type_arr
,extract(day from order_date) day
,time_window_for_second_order_complete
,is_churned_after_first_order
,is_retained_customer
from {{ ref('base_orderlines') }}
where order_date >='2023-01-01' and is_first_order
))
