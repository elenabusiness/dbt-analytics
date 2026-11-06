{#
  Raw timestamps arrive as ISO strings in UTC ('2026-07-01T09:30:00Z'). One place decides how they are parsed:
  as TIMESTAMP_NTZ holding the UTC wall-clock time. try_ returns NULL instead of failing on a bad string.
  Exercise: what would plain ::timestamp_tz do here, given a new account's TIMEZONE parameter is America/Los_Angeles?
#}
{% macro parse_ts(column) -%}
    try_to_timestamp_ntz({{ column }}, 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
{%- endmacro %}
