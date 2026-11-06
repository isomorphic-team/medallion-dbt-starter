-- Grain: one row per store. An aggregate mart for the questions asked most often.
-- Opening units are the first inventory count per store.
with opening_count as (
    select store_key, min(date_key) as count_date
    from {{ ref('fct_inventory_snapshot') }}
    group by store_key
),

opening as (
    select i.store_key, sum(i.units_on_hand) as opening_units
    from {{ ref('fct_inventory_snapshot') }} as i
    inner join opening_count as o on i.store_key = o.store_key and i.date_key = o.count_date
    group by i.store_key
),

sales as (
    select
        store_key,
        sum(units_sold)                                                     as units_sold,
        sum(net_sales)                                                      as net_sales,
        sum(gross_margin)                                                   as gross_margin,
        sum(case when cost_of_goods is not null then net_sales end)         as net_sales_with_known_cost
    from {{ ref('fct_sales') }}
    group by store_key
)

select
    d.store_key,
    d.store_number,
    d.store_name,
    d.region,
    coalesce(o.opening_units, 0)                                            as opening_units,
    coalesce(s.units_sold, 0)                                               as units_sold,
    coalesce(s.net_sales, 0)                                                as net_sales,
    s.gross_margin,
    {{ gross_margin_rate('s.gross_margin', 's.net_sales_with_known_cost') }}  as gross_margin_rate,
    {{ sell_through('coalesce(s.units_sold, 0)', 'o.opening_units') }}      as sell_through
from {{ ref('dim_store') }} as d
left join opening as o on d.store_key = o.store_key
left join sales as s on d.store_key = s.store_key
where d.store_key != {{ unknown_key() }}
