{{ config(
  materialized='table',
  schema = 'staging',
  
  ) }}
-- -- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__logistic_reg`
-- -- OPTIONS
-- --   (model_type='logistic_reg',
-- --    input_label_cols=['orders_successfull_followup']) AS
-- -- select * 
-- -- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- -- where split = 'train';


-- -- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__linear_reg`
-- -- OPTIONS
-- --   (model_type='linear_reg',
-- --    input_label_cols=['orders_successfull_followup']) AS
-- -- select * 
-- -- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- -- where split = 'train';


-- -- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__boosted_tree_regressor`
-- -- OPTIONS
-- --   (model_type='boosted_tree_regressor',
-- --   max_iterations= 200,  
-- --     learn_rate= 0.1,  # Decrease from 0.30
-- --     min_rel_progress= 0.001,  # Make this more stringent
-- --     L1_reg= 0.01,  # Adjust this value
-- --     L2_reg= 1.00 , # Ad
-- --    input_label_cols=['orders_successfull_followup']) AS
-- -- select * 
-- -- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- -- where split = 'train';

-- -- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__boosted_tree_regressor`
-- -- OPTIONS
-- --   (model_type='boosted_tree_regressor',
-- --   max_iterations=100,
-- --    input_label_cols=['orders_successfull_followup']) AS
-- -- select * 
-- -- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- -- where split = 'train';


-- -- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__deep_nn_classifier`
-- -- OPTIONS
-- --   (model_type='dnn_classifier',
-- --   hidden_units=[64, 32, 16, 16],
-- --    input_label_cols=['orders_successfull_followup']) AS
-- -- select * 
-- -- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- -- where split = 'train';


-- -- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__deep_nn_regressor`
-- -- OPTIONS
-- --   (model_type='dnn_regressor',
-- --   hidden_units=[64, 32, 16, 16],
-- --    input_label_cols=['orders_successfull_followup']) AS
-- -- select * 
-- -- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- -- where split = 'train';


-- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__random_forest_classifier__is_following_1_order_success`
-- OPTIONS
--   (model_type='random_forest_classifier',

--   input_label_cols=['is_following_1_order_success']) AS
-- select 
-- is_sub
-- ,vwo
-- ,sub_frequency_days
-- ,discount_percent_first_order
-- ,discount_percent_max
-- ,discount_percent_total
-- ,price
-- ,sub_ids_other_active
-- ,is_new_customer
-- ,sub_ids_cancelled_before 
-- ,sub_ids_cancelled_before_rate
-- ,orders_refunded_before_rate
-- ,orders_refunded_sequentially_latest
-- ,orders_before_from_customer
-- ,payment_offset_days_median_days
-- ,customer_had_early_cancellation
-- ,early_cancellation_avg_rate
-- ,is_following_1_order_success
-- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- where split = 'train'
-- and is_following_1_order_success is not null;



-- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__random_forest_classifier__is_following_2_order_success`
-- OPTIONS
--   (model_type='random_forest_classifier',

--   input_label_cols=['is_following_2_order_success']) AS
-- select 
-- is_sub
-- ,vwo
-- ,sub_frequency_days
-- ,discount_percent_first_order
-- ,discount_percent_max
-- ,discount_percent_total
-- ,price
-- ,sub_ids_other_active
-- ,is_new_customer
-- ,sub_ids_cancelled_before 
-- ,sub_ids_cancelled_before_rate
-- ,orders_refunded_before_rate
-- ,orders_refunded_sequentially_latest
-- ,orders_before_from_customer
-- ,payment_offset_days_median_days
-- ,customer_had_early_cancellation
-- ,early_cancellation_avg_rate
-- ,is_following_2_order_success
-- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- where split = 'train'
-- and is_following_2_order_success is not null;



-- CREATE OR REPLACE MODEL `wuffes-data.customers_forecast.subs_forecast_data_model__random_forest_classifier__is_following_3_order_success`
-- OPTIONS
--   (model_type='random_forest_classifier',

--   input_label_cols=['is_following_3_order_success']) AS
-- select 
-- is_sub
-- ,vwo
-- ,sub_frequency_days
-- ,discount_percent_first_order
-- ,discount_percent_max
-- ,discount_percent_total
-- ,price
-- ,sub_ids_other_active
-- ,is_new_customer
-- ,sub_ids_cancelled_before 
-- ,sub_ids_cancelled_before_rate
-- ,orders_refunded_before_rate
-- ,orders_refunded_sequentially_latest
-- ,orders_before_from_customer
-- ,payment_offset_days_median_days
-- ,customer_had_early_cancellation
-- ,early_cancellation_avg_rate
-- ,is_following_3_order_success
-- from `wuffes-data.customers_forecast.subs_forecast_data_split` 
-- where split = 'train'
-- and is_following_3_order_success is not null;





