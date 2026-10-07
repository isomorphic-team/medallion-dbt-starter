-- Grain: one row per deal.
select
    deal_id,
    deal_name,
    deal_type,
    start_date,
    end_date,
    status,
    case when status = 'closed' then 1 else 0 end as is_closed
from {{ ref('bronze__deals') }}
