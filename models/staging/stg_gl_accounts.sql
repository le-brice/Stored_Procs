select
    glaccountid as gl_account_id,
    accountcode as account_code,
    accountname as account_name,
    accounttype as account_type,
    isactive as is_active
from {{ ref('gl_account') }}
