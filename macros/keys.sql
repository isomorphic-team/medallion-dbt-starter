{#
  Surrogate keys for gold dimensions. A key is a hash of the natural key, so it is stable
  across rebuilds and identical on every warehouse dbt_utils supports.
  Facts that arrive with a natural key the dimension doesn't have point at the unknown
  member instead of dropping the row. See docs/modeling.md.
#}
{% macro unknown_key() -%}
    '-1'
{%- endmacro %}
