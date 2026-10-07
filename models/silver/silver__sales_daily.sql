-- Grain: one row per deal, store, SKU and day.
-- Exact duplicate rows are re-exports of the same file and are dropped.
-- Rows that disagree on the same grain are not guessed at: they aggregate, and the
-- reconciliation test in tests/ compares the result against the source total.
with deduplicated as (
    select distinct
        deal_id,
        store_number,
        trim(sku) as sku,
        sale_date,
        units_sold,
        gross_sales,
        discount_amount
    from {{ ref('bronze__sales') }}
)

select
    {{ dbt.concat(['deal_id', "'-'", 'store_number']) }} as store_key,
    deal_id,
    store_number,
    sku,
    sale_date,
    sum(units_sold)                                       as units_sold,
    sum(gross_sales)                                      as gross_sales,
    sum(discount_amount)                                  as discount_amount,
    sum(gross_sales - discount_amount)                    as net_sales
from deduplicated
group by deal_id, store_number, sku, sale_date
