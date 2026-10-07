-- Bronze: one view per raw table. Rename and cast. No filters, no joins, no business rules.
select
    {{ adapter.quote('DEAL_ID') }}                                      as deal_id,
    {{ adapter.quote('Deal Name') }}                                    as deal_name,
    {{ adapter.quote('Deal Type') }}                                    as deal_type,
    cast(nullif(trim({{ adapter.quote('Start Date') }}), '') as date)   as start_date,
    cast(nullif(trim({{ adapter.quote('End Date') }}), '') as date)     as end_date,
    {{ adapter.quote('Status') }}                                       as status
from {{ source('raw', 'raw_deals') }}
