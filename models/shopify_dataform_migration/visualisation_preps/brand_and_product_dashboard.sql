{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
config {
    type: "table",
    schema: "visualisation_preps"
}
with organic_urls as (
select [
'https://wuffes.com/',
'https://wuffes.com/collections/shop-all',
'https://wuffes.com/products/advanced-hip-joint-support-for-small-medium-breeds',
'https://wuffes.com/products/advanced-hip-joint-support-for-large-breeds',
'https://wuffes.com/products/wild-alaskan-salmon-oil-8oz',
'https://wuffes.com/products/wild-alaskan-salmon-oil',
'https://wuffes.com/products/23-in-1-multivitamin',
'https://wuffes.com/products/premium-joint-liquid',
'https://wuffes.com/products/portable-laser-therapy',
'https://cbd.wuffes.com/products/cbd-isolate-oil',
'https://wuffes.com/pages/bundle-quiz',
'https://wuffes.com/pages/faq',
'https://wuffes.com/pages/warranty',
'https://wuffes.com/pages/contact-us',
'https://wuffes.com/pages/join-us',
'https://wuffes.com/blogs/news',
'https://wuffes.com/pages/terms-of-service',
'https://wuffes.com/pages/privacy-policy'] urls
)
,base as (
select
order_date
,customer_id
,if(is_first_order,'New Customer','Returning Customer') customer_type
,order_id
,is_first_order
,billing_address_country country
,billing_address_state state
,billing_address_state_code state_code
,order_has_sub
,is_sub,sub_id
,sub_frequency_group sub_frequency
,dog_weight_from_product dog_weight
,sku
,orderline_name 
,orderline_quantity
,orderline_revenue Revenue
,orderline_cm_less_cac CM
,orderline_paid_by_customer gross_sales
,if (is_first_order,orderline_revenue,null) Revenue_day_0
,if (is_first_order,orderline_cm_less_cac,null) CM_day_0
,if(is_sub,max(trim(lower(source_url))) over (partition by sub_id),source_url) source_url

from {{ ref('base_orderlines') }}
)

,organic_url_check as (
select * except(urls)
,ifnull(trim(lower(source_url)) in unnest(organic_urls.urls),false) is_organic
from base 
cross join organic_urls 
)

,union_table as (
select 
order_date
,customer_id
,customer_type
,order_id
,is_first_order
,country
,state
,state_code
,order_has_sub
,is_sub
,sub_id
,sub_frequency
,dog_weight
,sku
,orderline_name 
,orderline_quantity
,Revenue organic_revenue
,gross_sales organic_gross_sales
,Revenue_day_0
,CM_day_0
,source_url
,null cpc_revenue
,null cpc_gross_sales
from organic_url_check
where is_organic

union all

select
order_date
,customer_id
,customer_type
,null order_id
,is_first_order
,country
,state
,state_code
,order_has_sub
,is_sub
,sub_id
,sub_frequency
,dog_weight
,null sku
,null orderline_name 
,null orderline_quantity
,null organic_revenue 
,null organic_gross_sales
,null Revenue_day_0
,null CM_day_0
,null source_url
,Revenue cpc_revenue 
,gross_sales cpc_gross_sales
from organic_url_check
where not(is_organic)
)

select 
*
from union_table