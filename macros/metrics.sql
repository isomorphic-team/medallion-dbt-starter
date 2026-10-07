{#
  Business definitions live here, once. Gold models call them; nothing re-derives them.
  These are placeholders. Confirm each with the business owner before anyone quotes a number.
#}

{# Recovery rate: net sales realized as a share of the cost value of inventory. #}
{% macro recovery_rate(net_sales, cost_value) -%}
    cast({{ net_sales }} as {{ dbt.type_numeric() }}) / nullif(cast({{ cost_value }} as {{ dbt.type_numeric() }}), 0)
{%- endmacro %}

{# Sell-through: units sold as a share of opening units. Cast first so integer division can't truncate. #}
{% macro sell_through(units_sold, units_on_hand) -%}
    cast({{ units_sold }} as {{ dbt.type_numeric() }}) / nullif(cast({{ units_on_hand }} as {{ dbt.type_numeric() }}), 0)
{%- endmacro %}
