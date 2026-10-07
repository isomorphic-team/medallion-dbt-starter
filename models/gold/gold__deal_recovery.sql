-- Grain: one row per deal. What the deal recovered against the cost of what it started with.
with inventory as (
    select deal_id, sum(units_on_hand) as units_on_hand, sum(cost_value) as cost_value
    from {{ ref('silver__inventory_position') }}
    group by deal_id
),

sales as (
    select deal_id, sum(units_sold) as units_sold, sum(net_sales) as net_sales
    from {{ ref('silver__sales_daily') }}
    group by deal_id
)

select
    d.deal_id,
    d.deal_name,
    d.deal_type,
    d.status,
    d.start_date,
    d.end_date,
    coalesce(i.units_on_hand, 0)                                        as units_on_hand,
    coalesce(i.cost_value, 0)                                           as cost_value,
    coalesce(s.units_sold, 0)                                           as units_sold,
    coalesce(s.net_sales, 0)                                            as net_sales,
    {{ recovery_rate('coalesce(s.net_sales, 0)', 'i.cost_value') }}     as recovery_rate,
    {{ sell_through('coalesce(s.units_sold, 0)', 'i.units_on_hand') }}  as sell_through
from {{ ref('silver__deals') }} as d
left join inventory as i on d.deal_id = i.deal_id
left join sales as s on d.deal_id = s.deal_id
