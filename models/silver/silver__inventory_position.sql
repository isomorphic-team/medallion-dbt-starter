-- Grain: one row per deal, store and SKU. Opening position at deal start.
select
    {{ dbt.concat(['deal_id', "'-'", 'store_number']) }} as store_key,
    deal_id,
    store_number,
    trim(sku)                                             as sku,
    category,
    units_on_hand,
    unit_cost,
    units_on_hand * unit_cost                             as cost_value
from {{ ref('bronze__inventory') }}
