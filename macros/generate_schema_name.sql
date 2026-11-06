{#
  Where does a model land?  dbt's default is <target schema>_<custom schema> everywhere.
  This override keeps that in dev (dbt_elena_staging, dbt_elena_marts: your own sandbox) but uses the
  bare custom name in prod (STAGING, MARTS), which is what most teams do.
  Interview question: why not just use the bare name in dev too?
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ target.schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
