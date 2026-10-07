-- Grain: one row per deal and store.
with inventory as (
    select store_key, sum(units_on_hand) as units_on_hand, sum(cost_value) as cost_value
    from {{ ref('silver__inventory_position') }}
    group by store_key
),

sales as (
    select store_key, sum(units_sold) as units_sold, sum(net_sales) as net_sales
    from {{ ref('silver__sales_daily') }}
    group by store_key
)

select
    st.store_key,
    st.deal_id,
    st.store_number,
    st.city,
    st.state,
    coalesce(i.cost_value, 0)                                           as cost_value,
    coalesce(s.units_sold, 0)                                           as units_sold,
    coalesce(s.net_sales, 0)                                            as net_sales,
    {{ recovery_rate('coalesce(s.net_sales, 0)', 'i.cost_value') }}     as recovery_rate,
    {{ sell_through('coalesce(s.units_sold, 0)', 'i.units_on_hand') }}  as sell_through
from {{ ref('silver__stores') }} as st
left join inventory as i on st.store_key = i.store_key
left join sales as s on st.store_key = s.store_key
