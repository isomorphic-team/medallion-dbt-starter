select
    {{ adapter.quote('Store #') }}                                              as store_number,
    {{ adapter.quote('SKU') }}                                                  as sku,
    cast({{ adapter.quote('Count Date') }} as date)                             as count_date,
    cast({{ adapter.quote('Units On Hand') }} as {{ dbt.type_int() }})          as units_on_hand
from {{ source('raw', 'raw_inventory') }}
