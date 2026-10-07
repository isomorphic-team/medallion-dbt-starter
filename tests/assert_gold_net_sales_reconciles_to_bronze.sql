-- Reconciliation: every dollar in bronze reaches gold, no more and no less.
-- Catches rows dropped or doubled by joins between silver and gold, the failure that
-- compiles, runs and returns a plausible number. Returns rows only when totals disagree.
with bronze_total as (
    select sum(gross_sales - discount_amount) as net_sales
    from (
        select distinct deal_id, store_number, trim(sku) as sku, sale_date,
                        units_sold, gross_sales, discount_amount
        from {{ ref('bronze__sales') }}
    ) as deduplicated
),

gold_total as (
    select sum(net_sales) as net_sales
    from {{ ref('gold__deal_recovery') }}
)

select b.net_sales as bronze_net_sales, g.net_sales as gold_net_sales
from bronze_total as b
cross join gold_total as g
where abs(b.net_sales - g.net_sales) > 0.01
