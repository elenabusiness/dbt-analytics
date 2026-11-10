{% macro run_query_print(sql) %}
  {% set results = run_query(sql) %}
  {% for row in results %}
    {{ log(row.values() | list, info=True) }}
  {% endfor %}
{% endmacro %}
