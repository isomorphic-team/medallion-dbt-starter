select
    {{ adapter.quote('SKU') }}                                                  as sku,
    {{ adapter.quote('Product Name') }}                                         as product_name,
    {{ adapter.quote('Category') }}                                             as category,
    cast({{ adapter.quote('Unit Cost') }} as {{ dbt.type_numeric() }})          as unit_cost,
    cast({{ adapter.quote('List Price') }} as {{ dbt.type_numeric() }})         as list_price
from {{ source('raw', 'raw_products') }}
