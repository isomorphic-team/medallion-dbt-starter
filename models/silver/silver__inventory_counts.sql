-- Grain: one row per store, SKU and count date.
select
    trim(store_number)  as store_number,
    upper(trim(sku))    as sku,
    count_date,
    units_on_hand
from {{ ref('bronze__inventory') }}
