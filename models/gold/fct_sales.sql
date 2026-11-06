-- Grain: one row per store, SKU and day. A transaction fact rolled up to the day.
-- sku stays on the fact as a degenerate dimension so unknown products remain traceable.
select
    coalesce(st.store_key, {{ unknown_key() }})     as store_key,
    coalesce(p.product_key, {{ unknown_key() }})    as product_key,
    s.sale_date                                     as date_key,
    s.sku,
    s.units_sold,
    s.gross_sales,
    s.discount_amount,
    s.net_sales,
    s.units_sold * p.unit_cost                      as cost_of_goods,
    s.net_sales - s.units_sold * p.unit_cost        as gross_margin
from {{ ref('silver__sales') }} as s
left join {{ ref('dim_store') }} as st on s.store_number = st.store_number
left join {{ ref('dim_product') }} as p on s.sku = p.sku
