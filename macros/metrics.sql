{#
  Business definitions live here, once. Gold models call them; nothing re-derives them.
  These are example definitions. Confirm each with the business owner before anyone quotes a number.
#}

{# Gross margin rate: margin as a share of the net sales it was earned on. Cast first so integer division can't truncate. #}
{% macro gross_margin_rate(gross_margin, net_sales) -%}
    cast({{ gross_margin }} as {{ dbt.type_numeric() }}) / nullif(cast({{ net_sales }} as {{ dbt.type_numeric() }}), 0)
{%- endmacro %}

{# Sell-through: units sold as a share of opening units on hand. #}
{% macro sell_through(units_sold, opening_units) -%}
    cast({{ units_sold }} as {{ dbt.type_numeric() }}) / nullif(cast({{ opening_units }} as {{ dbt.type_numeric() }}), 0)
{%- endmacro %}
