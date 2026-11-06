-- Grain: one row per store, SKU and day.
-- Exact duplicate rows are re-exports of the same file and are dropped.
-- Rows that differ on the same grain are real sales: they aggregate, and the
-- reconciliation test in tests/ checks the result against the bronze total.
with deduplicated as (
    select distinct
        trim(store_number)  as store_number,
        upper(trim(sku))    as sku,
        sale_date,
        units_sold,
        gross_sales,
        discount_amount
    from {{ ref('bronze__sales') }}
)

select
    store_number,
    sku,
    sale_date,
    sum(units_sold)                     as units_sold,
    sum(gross_sales)                    as gross_sales,
    sum(discount_amount)                as discount_amount,
    sum(gross_sales - discount_amount)  as net_sales
from deduplicated
group by store_number, sku, sale_date
