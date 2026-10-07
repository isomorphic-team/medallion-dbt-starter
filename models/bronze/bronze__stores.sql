select
    {{ adapter.quote('Store #') }}                                      as store_number,
    {{ adapter.quote('DEAL_ID') }}                                      as deal_id,
    {{ adapter.quote('City') }}                                         as city,
    {{ adapter.quote('State') }}                                        as state,
    cast({{ adapter.quote('Sq Ft') }} as {{ dbt.type_int() }})          as square_feet
from {{ source('raw', 'raw_stores') }}
