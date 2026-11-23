CREATE OR REPLACE FUNCTION guardops.connections_in_plain_words()
 RETURNS text
 LANGUAGE sql
 SET search_path TO 'guardops', 'pg_temp'
AS $function$
select case when count(*) = 0
         then 'No database has been connected by sign-in yet.'
         else 'Connected by sign-in: ' || string_agg(coalesce(org_slug,'(account)') || ' since ' ||
              to_char(approved_at at time zone 'Asia/Karachi','FMDD FMMonth, FMHH12:MI AM'), '; ')
       end
from guardops.connected_account where status = 'ACTIVE';
$function$
