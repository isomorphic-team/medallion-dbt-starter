-- Grain: one row per calendar day between the calendar_start and calendar_end vars.
-- Built from a date spine, not from the facts, so days with no activity still exist.
with spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('" ~ var('calendar_start') ~ "' as date)",
        end_date="cast('" ~ var('calendar_end') ~ "' as date)"
    ) }}
)

select
    cast(date_day as date)                                  as date_key,
    cast({{ dbt.date_trunc('week', 'date_day') }} as date)      as week_start,
    cast({{ dbt.date_trunc('month', 'date_day') }} as date)     as month_start,
    cast({{ dbt.date_trunc('quarter', 'date_day') }} as date)   as quarter_start,
    cast({{ dbt.date_trunc('year', 'date_day') }} as date)      as year_start
from spine
