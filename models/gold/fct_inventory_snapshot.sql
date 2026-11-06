-- Grain: one row per store, SKU and count date. A periodic snapshot fact.
-- Units on hand are semi-additive: sum them across stores and products, never across dates.
select
    coalesce(st.store_key, {{ unknown_key() }})     as store_key,
    coalesce(p.product_key, {{ unknown_key() }})    as product_key,
    i.count_date                                    as date_key,
    i.sku,
    i.units_on_hand,
    i.units_on_hand * p.unit_cost                   as cost_value
from {{ ref('silver__inventory_counts') }} as i
left join {{ ref('dim_store') }} as st on i.store_number = st.store_number
left join {{ ref('dim_product') }} as p on i.sku = p.sku
