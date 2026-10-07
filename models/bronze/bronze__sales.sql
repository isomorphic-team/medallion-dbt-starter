select
    {{ adapter.quote('DEAL_ID') }}                                              as deal_id,
    {{ adapter.quote('Store #') }}                                              as store_number,
    {{ adapter.quote('SKU') }}                                                  as sku,
    cast({{ adapter.quote('Sale Date') }} as date)                              as sale_date,
    cast({{ adapter.quote('Units Sold') }} as {{ dbt.type_int() }})             as units_sold,
    cast({{ adapter.quote('Gross Sales') }} as {{ dbt.type_numeric() }})        as gross_sales,
    cast({{ adapter.quote('Discount Amt') }} as {{ dbt.type_numeric() }})       as discount_amount
from {{ source('raw', 'raw_sales') }}
