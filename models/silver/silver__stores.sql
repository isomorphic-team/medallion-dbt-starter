-- Grain: one row per store.
select
    trim(store_number)  as store_number,
    trim(store_name)    as store_name,
    trim(city)          as city,
    upper(trim(state))  as state,
    trim(region)        as region,
    square_feet,
    opened_on
from {{ ref('bronze__stores') }}
