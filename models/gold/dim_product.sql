-- Grain: one row per SKU, plus one unknown member.
-- Type 1: attributes are overwritten when the source changes. See docs/modeling.md for Type 2.
select
    {{ dbt_utils.generate_surrogate_key(['sku']) }}  as product_key,
    sku,
    product_name,
    category,
    unit_cost,
    list_price
from {{ ref('silver__products') }}

union all

select
    {{ unknown_key() }}                         as product_key,
    'unknown'                                   as sku,
    'Unknown product'                           as product_name,
    'Unknown'                                   as category,
    cast(null as {{ dbt.type_numeric() }})      as unit_cost,
    cast(null as {{ dbt.type_numeric() }})      as list_price
