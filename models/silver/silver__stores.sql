-- Grain: one row per deal and store.
-- Store numbers repeat across deals (every retailer has a store 101), so the key includes the deal.
select
    {{ dbt.concat(['deal_id', "'-'", 'store_number']) }} as store_key,
    deal_id,
    store_number,
    city,
    state,
    square_feet
from {{ ref('bronze__stores') }}
