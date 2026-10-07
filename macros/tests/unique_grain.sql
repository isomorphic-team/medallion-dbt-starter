{#
  One row per combination of `columns`. Put this on every silver and gold model.
  The grain is the contract; this test is how the contract is enforced.
#}
{% test unique_grain(model, columns) %}
select {{ columns | join(', ') }}, count(*) as n
from {{ model }}
group by {{ columns | join(', ') }}
having count(*) > 1
{% endtest %}
