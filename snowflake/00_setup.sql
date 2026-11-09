-- 00_setup.sql: the account's foundations. ALREADY RUN on your trial account (4 Nov 2026);
-- every statement is idempotent, so running it again changes nothing.
-- Read it top to bottom: almost every line here is a classic interview question.
--
-- The shape is the one most dbt + Snowflake teams use:
--   RAW database        <- the loader writes here (Airflow / COPY INTO / Fivetran in real life)
--   ANALYTICS database  <- dbt builds here (one schema per developer + the production schemas)
--   three functional roles: LOADER (writes RAW), TRANSFORMER (reads RAW, writes ANALYTICS),
--   REPORTER (reads ANALYTICS only; what a BI tool would use)
--   one SERVICE user for the pipeline, signing in with a key pair, never a password.

use role accountadmin;

-- 1. Compute. X-Small = 1 credit/hour, billed per second after the first minute.
--    auto_suspend 60 s means an idle warehouse stops costing money after a minute.
create warehouse if not exists transform_wh
  warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true
  comment = 'dbt runs and ad-hoc queries';
create warehouse if not exists loading_wh
  warehouse_size = xsmall auto_suspend = 60 auto_resume = true initially_suspended = true
  comment = 'COPY INTO / loads, kept apart so loads and transforms never queue behind each other';

-- 2. A spending guard: the trial has $400 of credits; this stops the warehouses at 40 credits a month.
create resource monitor if not exists trial_guard with credit_quota = 40
  frequency = monthly start_timestamp = immediately
  triggers on 75 percent do notify
           on 100 percent do suspend;
alter warehouse transform_wh set resource_monitor = trial_guard;
alter warehouse loading_wh   set resource_monitor = trial_guard;

-- 3. Storage.
create database if not exists raw comment = 'landing zone: source data exactly as delivered';
create database if not exists analytics comment = 'everything dbt builds';

-- 4. Roles. securityadmin owns roles and grants; sysadmin owns objects.
use role securityadmin;
create role if not exists loader      comment = 'writes RAW';
create role if not exists transformer comment = 'reads RAW, builds ANALYTICS (dbt)';
create role if not exists reporter    comment = 'reads ANALYTICS (BI tools, analysts)';

-- custom roles roll up to sysadmin, so sysadmin can see and manage everything they create
grant role loader      to role sysadmin;
grant role transformer to role sysadmin;
grant role reporter    to role sysadmin;

-- 5. Privileges.
grant usage on warehouse loading_wh   to role loader;
grant usage on warehouse transform_wh to role transformer;
grant usage on warehouse transform_wh to role reporter;

grant usage, create schema on database raw to role loader;
grant usage on database raw to role transformer;
-- FUTURE grants: tables the loader creates later are readable by dbt without anyone re-granting
grant usage on future schemas in database raw to role transformer;
grant select on future tables in database raw to role transformer;
grant select on future views  in database raw to role transformer;

grant usage, create schema on database analytics to role transformer;
grant usage on database analytics to role reporter;
grant usage on future schemas in database analytics to role reporter;
grant select on future tables in database analytics to role reporter;
grant select on future views  in database analytics to role reporter;

-- 6. The pipeline's service user. TYPE = SERVICE: no password, no MFA prompt, key pair only.
--    Your public key goes in RSA_PUBLIC_KEY (guide step 4). RSA_PUBLIC_KEY_2 is the second slot
--    Snowflake gives every user so keys can be rotated without downtime.
create user if not exists pipeline_svc
  type = service
  default_role = transformer
  default_warehouse = transform_wh
  comment = 'dbt + Airflow';
grant role loader      to user pipeline_svc;
grant role transformer to user pipeline_svc;

-- 7. You (ELENA) keep ACCOUNTADMIN and can also step into each functional role,
--    which is how you test "can dbt actually see this table?" questions.
grant role loader      to user elena;
grant role transformer to user elena;
grant role reporter    to user elena;
