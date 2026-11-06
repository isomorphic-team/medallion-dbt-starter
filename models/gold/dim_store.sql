-- Grain: one row per store, plus one unknown member.
-- Type 1: attributes are overwritten when the source changes. See docs/modeling.md for Type 2.
select
    {{ dbt_utils.generate_surrogate_key(['store_number']) }}  as store_key,
    store_number,
    store_name,
    city,
    state,
    region,
    square_feet,
    opened_on
from {{ ref('silver__stores') }}

union all

select
    {{ unknown_key() }}                     as store_key,
    'unknown'                               as store_number,
    'Unknown store'                         as store_name,
    cast(null as {{ dbt.type_string() }})   as city,
    cast(null as {{ dbt.type_string() }})   as state,
    'Unknown'                               as region,
    cast(null as {{ dbt.type_int() }})      as square_feet,
    cast(null as date)                      as opened_on
