select
    {{ adapter.quote('DEAL_ID') }}                                              as deal_id,
    {{ adapter.quote('Store #') }}                                              as store_number,
    {{ adapter.quote('SKU') }}                                                  as sku,
    {{ adapter.quote('Category') }}                                             as category,
    cast({{ adapter.quote('Units On Hand') }} as {{ dbt.type_int() }})          as units_on_hand,
    cast({{ adapter.quote('Unit Cost') }} as {{ dbt.type_numeric() }})          as unit_cost
from {{ source('raw', 'raw_inventory') }}
