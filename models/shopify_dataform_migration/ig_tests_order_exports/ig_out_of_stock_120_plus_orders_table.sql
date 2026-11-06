{{ config(
  materialized='table',
  schema = 'staging',
  enabled = false,
  ) }}
config {
type: "operations",
}

create schema if not exists `${settings.google_sheet_dataset_ref}`;
CREATE OR REPLACE EXTERNAL TABLE `${settings.ig_out_of_stock_120_plus_orders_table_table_ref}`
(
variation_name STRING
,order_id STRING
,order_name STRING
,customer_id STRING
,order_created_time STRING
,shipping_method STRING
,test_order STRING
,total_units STRING
,total_test_units STRING
,product_list_price STRING
,product_discount STRING
,intelligems_price_test_discount STRING
,net_product_revenue STRING
,net_shipping_revenue STRING
,net_revenue STRING
,total_tax STRING
,net_revenue_incl_tax_and_tip STRING
,product_cogs STRING
,shipping_cost STRING
,transaction_fee STRING
,gross_profit STRING
,order_value_z_score STRING
,is_outlier BOOL
,subscription_order_type STRING
,new_vs_returning_visitor STRING
,device_type STRING
,channel STRING
,timezone STRING
,label STRING
)

OPTIONS (
  format = 'GOOGLE_SHEETS',
  skip_leading_rows = ${settings.ig_out_of_stock_orders_table_skip_leading_rows},
  sheet_range = "${settings.ig_out_of_stock_120_plus_orders_table_sheet_range}",
  uris = ["${settings.ig_out_of_stock_orders_table}"]
);
