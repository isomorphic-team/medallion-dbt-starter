-- Grain: one row per SKU.
select
    upper(trim(sku))    as sku,
    trim(product_name)  as product_name,
    trim(category)      as category,
    unit_cost,
    list_price
from {{ ref('bronze__products') }}
