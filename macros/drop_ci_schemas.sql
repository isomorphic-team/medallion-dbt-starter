{#
  Drops the schemas a PR build created. Called by .github/workflows/cleanup.yml.
  Refuses to run against prod.
  dbt run-operation drop_ci_schemas --target ci_warehouse
#}
{% macro drop_ci_schemas() %}
    {% if target.name == 'prod' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas never runs against prod") }}
    {% endif %}
    {% for layer in ['raw', 'bronze', 'silver', 'gold'] %}
        {% set schema = target.schema ~ '_' ~ layer %}
        {% do adapter.drop_schema(api.Relation.create(database=target.database, schema=schema)) %}
        {{ log("dropped " ~ schema, info=true) }}
    {% endfor %}
{% endmacro %}
