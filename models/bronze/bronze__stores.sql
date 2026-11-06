select
    {{ adapter.quote('Store #') }}                                      as store_number,
    {{ adapter.quote('Store Name') }}                                   as store_name,
    {{ adapter.quote('City') }}                                         as city,
    {{ adapter.quote('State') }}                                        as state,
    {{ adapter.quote('Region') }}                                       as region,
    cast({{ adapter.quote('Sq Ft') }} as {{ dbt.type_int() }})          as square_feet,
    cast(nullif(trim({{ adapter.quote('Opened On') }}), '') as date)    as opened_on
from {{ source('raw', 'raw_stores') }}
